# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
# Purpose: Multi-pack consumer engine. Downloads release assets, verifies sha256, applies files, and pushes directly to base branch.

[CmdletBinding()]
param(
  [string]$PacksPath = ".automation/packs.json",
  [string]$LockDir = ".automation/lock",
  [string]$BackupDir = ".automation/backup",
  [string]$WorkDir = ".automation/.tmp",
  [string]$OnlyId = ""
)

Set-StrictMode -Version Latest

function Get-OptionalProp([object]$obj, [string]$name) {
  if ($null -eq $obj) { return $null }

  # Support both PSCustomObject and IDictionary/Hashtable
  if ($obj -is [System.Collections.IDictionary]) {
    try {
      if ($obj.Contains($name)) { return $obj[$name] }
    } catch {}
    try {
      if ($obj.ContainsKey($name)) { return $obj[$name] }
    } catch {}
    return $null
  }

  $p = $obj.PSObject.Properties[$name]
  if ($null -ne $p) { return $p.Value }
  return $null
}

$ErrorActionPreference = "Stop"

function EnsureDir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function ReadJson([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
  return $raw | ConvertFrom-Json
}

function WriteJson([string]$Path, $Obj) {
  $dir = Split-Path -Parent $Path
  EnsureDir $dir
  ($Obj | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Sha256File([string]$Path) {
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Git {
  param(
    # Collect all positional arguments safely. Do not use $Args (reserved automatic variable).
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GitArgs
  )

  if (-not $GitArgs -or $GitArgs.Count -eq 0) {
    throw "git failed: <empty arguments>"
  }

  Write-Host ("git {0}" -f ($GitArgs -join ' '))

  # PowerShell resolves commands case-insensitively.
  # This file defines function `Git`, so calling `git` here would recurse and overflow call depth.
  $gitExe = @((Get-Command git -All -CommandType Application -ErrorAction Stop).Path)[0]
  if (-not $gitExe) { throw "git not found" }
  & $gitExe @GitArgs
  if ($LASTEXITCODE -ne 0) {
    throw "git failed: $($GitArgs -join ' ')"
  }
}

function Gh([string[]]$Args) {
  if ($null -eq $Args) { $Args = @() }
  # Defensive: allow calling `Gh` with a REST endpoint directly (e.g. `repos/<o>/<r>/releases/latest`).
  # In that case, transparently prepend `api` so the call becomes `gh api ...`.
  if ($Args.Count -gt 0) {
    $a0 = [string]$Args[0]
    if ($a0 -match '^(repos|orgs|users|graphql)/') {
      $Args = @('api') + $Args
    }
  }
  $p = Start-Process -FilePath gh -ArgumentList $Args -NoNewWindow -Wait -PassThru
  if ($p.ExitCode -ne 0) { throw "gh failed: $($Args -join ' ')" }
}

function GhApi([string[]]$Args) {
  if ($null -eq $Args) { $Args = @() }
  Gh (@('api') + $Args)
}

function WithGhToken([string]$Token, [scriptblock]$Block) {
  $prev = $env:GH_TOKEN
  try {
    $env:GH_TOKEN = $Token
    & $Block
  } finally {
    $env:GH_TOKEN = $prev
  }
}

function ParseIsoDurationSeconds([string]$Dur) {
  if ([string]::IsNullOrWhiteSpace($Dur)) { return 0 }
  $d = $Dur.Trim().ToUpperInvariant()
  $rx = '^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$'
  $m = [regex]::Match($d, $rx)
  if (-not $m.Success) { throw "Invalid ISO duration: $Dur (expected PnD or PTnHnM or PnDTnHnM)" }
  $days = 0; $hours = 0; $mins = 0; $secs = 0
  if ($m.Groups[1].Success) { $days = [int]$m.Groups[1].Value }
  if ($m.Groups[2].Success) { $hours = [int]$m.Groups[2].Value }
  if ($m.Groups[3].Success) { $mins = [int]$m.Groups[3].Value }
  if ($m.Groups[4].Success) { $secs = [int]$m.Groups[4].Value }
  return ($days * 86400) + ($hours * 3600) + ($mins * 60) + $secs
}

function NowUtc() { return [DateTimeOffset]::UtcNow }

function ShouldThrottle([string]$PackId, [string]$TimerIso) {
  $triggerTag = [string]$env:AUTOMATER_TRIGGER_TAG
  if ([string]::IsNullOrWhiteSpace($triggerTag)) { $triggerTag = [string]$env:AUTOMATE_TRIGGER_TAG }

  $triggerPack = [string]$env:AUTOMATER_TRIGGER_PACK_ID
  if ([string]::IsNullOrWhiteSpace($triggerPack)) { $triggerPack = [string]$env:AUTOMATE_TRIGGER_PACK_ID }

  if (-not [string]::IsNullOrWhiteSpace($triggerTag)) {
    if ([string]::IsNullOrWhiteSpace($triggerPack) -or $triggerPack -eq $PackId) { return $false }
  }

  $lockPath = Join-Path $LockDir "$PackId.json"
  $lock = ReadJson $lockPath
  if (-not $lock) { return $false }

  $last = $null
  try { $last = [DateTimeOffset]::Parse([string]$lock.appliedAt) } catch { return $false }

  $seconds = ParseIsoDurationSeconds $TimerIso
  if ($seconds -le 0) { return $false }

  $age = ((NowUtc) - $last).TotalSeconds
  return ($age -lt $seconds)
}

function CopyTree([string]$FromDir, [string]$ToDir, [string]$PackId, [string]$Tag) {
  $files = Get-ChildItem -LiteralPath $FromDir -Recurse -File
  foreach ($f in $files) {
    $rel = $f.FullName.Substring($FromDir.Length).TrimStart('\','/')
    $dst = Join-Path $ToDir $rel
    $dstDir = Split-Path -Parent $dst
    EnsureDir $dstDir

    if (Test-Path -LiteralPath $dst) {
      $bakRoot = Join-Path $BackupDir $PackId
      $bakRoot = Join-Path $bakRoot $Tag
      $bak = Join-Path $bakRoot $rel
      $bakDir = Split-Path -Parent $bak
      EnsureDir $bakDir
      Copy-Item -LiteralPath $dst -Destination $bak -Force
    }

    Copy-Item -LiteralPath $f.FullName -Destination $dst -Force
  }
}

function GetLatestTag([string]$Owner, [string]$Repo, [string]$ReadToken) {
  EnsureDir $WorkDir

  $tag = $null

  # Best-effort: if gh is not authenticated (401) or release is absent (404),
  # we silently fall back to branch archive download.
  try {
    WithGhToken $ReadToken {
      $out = & gh api "repos/$Owner/$Repo/releases/latest" --jq ".tag_name" 2>&1
      if ($LASTEXITCODE -eq 0) {
        $tag = [string]$out
      }
    }
  } catch {
    $tag = $null
  }

  if ([string]::IsNullOrWhiteSpace($tag)) {
    return $null
  }

  return $tag.Trim()
}

function GetBranchHeadSha([string]$Owner, [string]$Repo, [string]$Branch, [string]$ReadToken) {
  $b = if ([string]::IsNullOrWhiteSpace($Branch)) { "master" } else { $Branch }
  $uri = "https://api.github.com/repos/$Owner/$Repo/commits/$b"
  $hdr = @{
    "User-Agent" = "automater-pack-sync"
    "Accept" = "application/vnd.github+json"
  }
  if (-not [string]::IsNullOrWhiteSpace($ReadToken)) { $hdr["Authorization"] = "Bearer $ReadToken" }
  try {
    $r = Invoke-RestMethod -Uri $uri -Headers $hdr -Method Get -ErrorAction Stop
    if ($null -eq $r) { return "" }
    return [string]$r.sha
  } catch {
    return ""
  }
}

function DownloadAssets([string]$Owner, [string]$Repo, [string]$Tag, [string]$ZipName, [string]$ShaName, [string]$ReadToken, [string]$Branch) {
  EnsureDir $WorkDir

  $useBranch = if ([string]::IsNullOrWhiteSpace($Branch)) { "master" } else { $Branch }
  $dlKey = if ([string]::IsNullOrWhiteSpace($Tag)) { ("branch-" + $useBranch) } else { $Tag.Replace("/","_") }

  $dlDir = Join-Path $WorkDir ("dl-" + $Owner + "-" + $Repo + "-" + $dlKey)
  if (Test-Path -LiteralPath $dlDir) { Remove-Item -Recurse -Force -LiteralPath $dlDir }
  New-Item -ItemType Directory -Path $dlDir | Out-Null
  # Preferred path: download release assets
  if (-not [string]::IsNullOrWhiteSpace($Tag)) {
    $zipPath = Join-Path $dlDir $ZipName
    $shaPath = Join-Path $dlDir $ShaName

    $ok = $false
    try {
      WithGhToken $ReadToken {
        Gh @("release","download",$Tag,"-R","$Owner/$Repo","-p",$ZipName,"-p",$ShaName,"-D",$dlDir)
      }
      if ((Test-Path -LiteralPath $zipPath) -and (Test-Path -LiteralPath $shaPath)) { $ok = $true }
    } catch {
      $ok = $false
    }

    if ($ok) {
      return @{ zip = $zipPath; sha = $shaPath; dir = $dlDir; tag = $Tag }
    }

    Write-Host "Release asset download failed or not available for $Owner/$Repo@$Tag. Falling back to branch archive '$useBranch'."
    # fall through into branch zipball path
  }

  # Fallback: repository has no releases yet — use branch zipball to bootstrap

  $zipPath = Join-Path $dlDir $ZipName
  $shaPath = Join-Path $dlDir $ShaName
  $url = "https://codeload.github.com/$Owner/$Repo/zip/refs/heads/$useBranch"
  Write-Host "No releases found for $Owner/$Repo. Downloading branch archive '$useBranch' from: $url"

  Invoke-WebRequest -Uri $url -OutFile $zipPath -Headers @{ "User-Agent"="automater-pack-sync" } -ErrorAction Stop
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLower()
  ($hash + "  " + $ZipName) | Set-Content -LiteralPath $shaPath -Encoding ASCII

  return @{ zip = $zipPath; sha = $shaPath; dir = $dlDir; tag = $null; branch = $useBranch }
}

function VerifySha([string]$ShaPath, [string]$ZipPath) {
  $expected = (Get-Content -LiteralPath $ShaPath -Raw -Encoding UTF8).Trim().Split(" ")[0].ToLowerInvariant()
  $actual = Sha256File $ZipPath
  if ($expected -ne $actual) { throw "SHA256 mismatch. expected=$expected actual=$actual" }
  return $actual
}

function ExtractZip([string]$ZipPath, [string]$ToDir) {
  if (Test-Path -LiteralPath $ToDir) { Remove-Item -Recurse -Force -LiteralPath $ToDir }
  New-Item -ItemType Directory -Path $ToDir | Out-Null
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ToDir)
}

if (-not (Test-Path -LiteralPath $PacksPath)) { throw "Missing packs config: $PacksPath" }

EnsureDir $LockDir
EnsureDir $BackupDir
EnsureDir $WorkDir

$config = ReadJson $PacksPath
if (-not $config) { throw "Invalid packs config: $PacksPath" }

$defaults = $config.defaults
$packs = @($config.packs)

if ($packs.Count -eq 0) { Write-Host "No packs configured."; exit 0 }

$baseBranch = $env:AUTOMATER_BASE_BRANCH
if ([string]::IsNullOrWhiteSpace($baseBranch)) { $baseBranch = $env:AUTOMATE_BASE_BRANCH }
if ([string]::IsNullOrWhiteSpace($baseBranch)) {
  $defBranch = Get-OptionalProp $defaults 'baseBranch'
  $baseBranch = $(if ($defBranch) { [string]$defBranch } else { "master" })
}

$writeToken = [string]$env:GITHUB_TOKEN
if ([string]::IsNullOrWhiteSpace($writeToken)) { throw "Missing GITHUB_TOKEN." }

$readToken = [string]$env:AUTOMATE_SOURCE_TOKEN

if ([string]::IsNullOrWhiteSpace($readToken)) { $readToken = [string]$env:AUTOMATER_SOURCE_TOKEN }
if ([string]::IsNullOrWhiteSpace($readToken)) { $readToken = $writeToken }

Git @("checkout",$baseBranch)
Git @("pull","--ff-only","origin",$baseBranch)

$globalTimer = $env:AUTOMATER_PUSH_TIMER
if ([string]::IsNullOrWhiteSpace($globalTimer)) { $globalTimer = $env:AUTOMATE_PUSH_TIMER }
if ([string]::IsNullOrWhiteSpace($globalTimer)) {
  $defTimer = Get-OptionalProp $defaults 'pushTimer'
  $globalTimer = $(if ($defTimer) { [string]$defTimer } else { "PT6H" })
}

$applied = New-Object System.Collections.Generic.List[object]

foreach ($pack in $packs) {
  $id = [string](Get-OptionalProp $pack 'id')
  if ([string]::IsNullOrWhiteSpace($id)) { continue }
  if (-not [string]::IsNullOrWhiteSpace($OnlyId) -and $id -ne $OnlyId) { continue }

  $src = Get-OptionalProp $pack 'source'
  $apply = Get-OptionalProp $pack 'apply'
  $defSrc = Get-OptionalProp $defaults 'source'
  $defApply = Get-OptionalProp $defaults 'apply'

  if (-not $src) { $src = $defSrc }
  if (-not $apply) { $apply = $defApply }
  if (-not $src) { throw "Pack $id missing source." }
  if (-not $apply) { throw "Pack $id missing apply." }

  $owner = [string](Get-OptionalProp $src 'owner')
  $repo  = [string](Get-OptionalProp $src 'repo')
  if ([string]::IsNullOrWhiteSpace($owner) -or [string]::IsNullOrWhiteSpace($repo)) { throw "Pack $id missing source owner/repo." }

  $zipName = [string](Get-OptionalProp $src 'assetZip')
  if (-not $zipName) { $zipName = [string](Get-OptionalProp $defSrc 'assetZip') }
  if (-not $zipName) { $zipName = "automate-kit.zip" }

  $shaName = [string](Get-OptionalProp $src 'assetSha')
  if (-not $shaName) { $shaName = [string](Get-OptionalProp $defSrc 'assetSha') }
  if (-not $shaName) { $shaName = "automate-kit.sha256" }

  $topFolder = [string](Get-OptionalProp $src 'topFolder')
  if (-not $topFolder) { $topFolder = [string](Get-OptionalProp $defSrc 'topFolder') }
  if ($null -eq $topFolder) { $topFolder = "" }

  $srcBranch = [string](Get-OptionalProp $src 'branch')
  if (-not $srcBranch) { $srcBranch = [string](Get-OptionalProp $defSrc 'branch') }
  if (-not $srcBranch) { $srcBranch = $baseBranch }

  $targetRoot = [string](Get-OptionalProp $apply 'targetRoot')
  if (-not $targetRoot) { $targetRoot = [string](Get-OptionalProp $defApply 'targetRoot') }
  if (-not $targetRoot) { $targetRoot = "." }

  $timer = [string](Get-OptionalProp $apply 'pushTimer')
  if ([string]::IsNullOrWhiteSpace($timer)) { $timer = $globalTimer }
  if (ShouldThrottle $id $timer) {
    Write-Host "Throttle: skip $id (timer=$timer)"
    continue
  }

  $triggerTag = [string]$env:AUTOMATER_TRIGGER_TAG
  if ([string]::IsNullOrWhiteSpace($triggerTag)) { $triggerTag = [string]$env:AUTOMATE_TRIGGER_TAG }

  $triggerPack = [string]$env:AUTOMATER_TRIGGER_PACK_ID
  if ([string]::IsNullOrWhiteSpace($triggerPack)) { $triggerPack = [string]$env:AUTOMATE_TRIGGER_PACK_ID }

  if (-not [string]::IsNullOrWhiteSpace($triggerTag) -and (-not [string]::IsNullOrWhiteSpace($triggerPack)) -and $triggerPack -ne $id) {
    continue
  }
  $tag = $null
  $downloadTag = $null
  if (-not [string]::IsNullOrWhiteSpace($triggerTag) -and ([string]::IsNullOrWhiteSpace($triggerPack) -or $triggerPack -eq $id)) {
    $tag = $triggerTag
    $downloadTag = $triggerTag
  } else {
    $latestTag = GetLatestTag $owner $repo $readToken
    if (-not [string]::IsNullOrWhiteSpace($latestTag)) {
      $tag = $latestTag
      $downloadTag = $latestTag
    } else {
      $headSha = GetBranchHeadSha $owner $repo $srcBranch $readToken
      if (-not [string]::IsNullOrWhiteSpace($headSha)) {
        $short = if ($headSha.Length -ge 8) { $headSha.Substring(0,8) } else { $headSha }
        $tag = "branch-$srcBranch-$short"
      } else {
        $tag = "branch-$srcBranch"
      }
      $downloadTag = $null
    }
  }
  $lockPath = Join-Path $LockDir "$id.json"
  $lock = ReadJson $lockPath
  if ($lock -and ([string]$lock.tag -eq [string]$tag)) {
    Write-Host "No update: $id already on $tag"
    continue
  }

  $dl = DownloadAssets $owner $repo $downloadTag $zipName $shaName $readToken $srcBranch
  $sha = VerifySha $dl.sha $dl.zip

  $extractRoot = Join-Path $dl.dir "extract"
  ExtractZip $dl.zip $extractRoot

  $payloadRoot = $extractRoot
  if (-not [string]::IsNullOrWhiteSpace($topFolder)) {
    $candidate = Join-Path $extractRoot $topFolder
    if (Test-Path -LiteralPath $candidate) { $payloadRoot = $candidate }
  }

  # Auto-detect GitHub zipball top folder when not configured.
  if ($payloadRoot -eq $extractRoot) {
    $entries = @((Get-ChildItem -LiteralPath $extractRoot -Force -ErrorAction SilentlyContinue))
    $dirs = @($entries | Where-Object { $_.PSIsContainer })
    $files = @($entries | Where-Object { -not $_.PSIsContainer })
    if ($dirs.Count -eq 1 -and $files.Count -eq 0) {
      $payloadRoot = $dirs[0].FullName
    }
  }

  if (-not (Test-Path -LiteralPath $payloadRoot)) { throw "Invalid payload root for $id at $payloadRoot" }

  $dstRoot = Resolve-Path -LiteralPath $targetRoot
  CopyTree $payloadRoot $dstRoot.Path $id $tag

  $lockObj = [pscustomobject]@{
    id = $id
    source = "$owner/$repo"
    tag = $tag
    sha256 = $sha
    appliedAt = ((NowUtc).ToString("o"))
  }
  WriteJson $lockPath $lockObj
  $applied.Add(@{ id = $id; tag = $tag }) | Out-Null

  Write-Host "Applied: $id@$tag"
}

$st = (git status --porcelain)
if ([string]::IsNullOrWhiteSpace($st)) {
  Write-Host "No changes to commit."
  exit 0
}

Git @("config","user.name","automater-bot")
Git @("config","user.email","automater-bot@users.noreply.github.com")

$parts = @()
foreach ($a in $applied) { $parts += ("{0}@{1}" -f $a.id, $a.tag) }
$msg = "automater pack sync: " + ($parts -join "; ")
if ($parts.Count -eq 0) { $msg = "automater pack sync" }

Git @("add","-A")
Git @("commit","-m",$msg)
Git @("push","origin",$baseBranch)

Write-Host "Pushed to $baseBranch."
