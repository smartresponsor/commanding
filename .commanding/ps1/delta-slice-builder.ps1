param(
  [string]$Root = "",
  [string]$BaseRef = "origin/master",
  [string]$HeadRef = "HEAD",
  [switch]$IncludeUntracked,

  [string]$OutDir = "report/slice",
  [string]$ZipFile = "",
  [switch]$WriteMap,

  [string[]]$ExcludeDir = @(),
  [string[]]$ExcludeExt = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Find-RepoRoot([string]$startPath) {
  $p = (Resolve-Path -LiteralPath $startPath).Path
  while ($true) {
    $gitDir = Join-Path $p ".git"
    $ghDir  = Join-Path $p ".github"

    if (Test-Path -LiteralPath $gitDir -PathType Container) { return $p }
    if (Test-Path -LiteralPath $ghDir  -PathType Container) { return $p }

    $parent = Split-Path -Parent $p
    if ($parent -eq $p -or [string]::IsNullOrWhiteSpace($parent)) { break }
    $p = $parent
  }
  return $null
}

function Load-SliceExcludePolicy([string]$repoRoot) {
  $p = Join-Path $repoRoot ".commanding/policy/slice-exclude.json"
  if (!(Test-Path -LiteralPath $p)) { return $null }
  try {
    $raw = Get-Content -LiteralPath $p -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Json)
  } catch {
    throw "Failed to read slice exclude policy at: $p"
  }
}

function Merge-Unique([string[]]$base, [object]$extra) {
  $set = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($x in $base) { if (![string]::IsNullOrWhiteSpace($x)) { [void]$set.Add($x) } }
  if ($null -ne $extra) {
    foreach ($x in $extra) { if (![string]::IsNullOrWhiteSpace($x)) { [void]$set.Add([string]$x) } }
  }
  return @($set)
}

function Normalize-RelPath([string]$p) {
  return ($p -replace '\\','/').TrimStart('/')
}

function Should-ExcludeRelPath([string]$rel) {
  $r = Normalize-RelPath $rel
  $parts = $r.Split('/')
  foreach ($seg in $parts) {
    foreach ($d in $ExcludeDir) {
      if ($seg -ieq $d) { return $true }
    }
  }
  $ext = [System.IO.Path]::GetExtension($r)
  if (![string]::IsNullOrWhiteSpace($ext)) {
    foreach ($e in $ExcludeExt) {
      if ($ext -ieq $e) { return $true }
    }
  }
  return $false
}

function Assert-GitAvailable() {
  $git = Get-Command git -ErrorAction SilentlyContinue
  if ($null -eq $git) { throw "git not found in PATH" }
}

function Get-GitDelta([string]$repoRoot, [string]$baseRef, [string]$headRef) {
  Push-Location $repoRoot
  try {
    $lines = git diff --name-status "$baseRef..$headRef"
    $items = @()
    foreach ($l in $lines) {
      if ([string]::IsNullOrWhiteSpace($l)) { continue }
      $cols = $l -split "`t"
      $statusRaw = $cols[0]
      if ($statusRaw -match '^R\d+$') {
        # Rename: R100 old new
        if ($cols.Length -ge 3) {
          $items += [pscustomobject]@{ status = "R"; path = $cols[2]; oldPath = $cols[1] }
        }
        continue
      }

      $status = $statusRaw.Trim()
      if ($cols.Length -ge 2) {
        $items += [pscustomobject]@{ status = $status; path = $cols[1]; oldPath = $null }
      }
    }

    if ($IncludeUntracked) {
      $u = git ls-files --others --exclude-standard
      foreach ($p in $u) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        $items += [pscustomobject]@{ status = "U"; path = $p; oldPath = $null }
      }
    }

    return $items
  } finally {
    Pop-Location
  }
}

function Ensure-Dir([string]$p) {
  if (!(Test-Path -LiteralPath $p)) {
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}

function Write-NdjsonLine([string]$file, [object]$obj) {
  ($obj | ConvertTo-Json -Compress) | Add-Content -LiteralPath $file -Encoding UTF8
}

function Add-FileToZip($zipArchive, [string]$repoRoot, [string]$relPath) {
  $r = Normalize-RelPath $relPath
  $abs = Join-Path $repoRoot $r
  if (!(Test-Path -LiteralPath $abs -PathType Leaf)) { return $false }

  $entryName = $r
  $entry = $zipArchive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
  $src = [System.IO.File]::OpenRead($abs)
  try {
    $dst = $entry.Open()
    try { $src.CopyTo($dst) } finally { $dst.Dispose() }
  } finally {
    $src.Dispose()
  }
  return $true
}

# --- Resolve repo root ---
$repoRoot = $null
if (![string]::IsNullOrWhiteSpace($Root)) {
  $repoRoot = Find-RepoRoot $Root
} else {
  $repoRoot = Find-RepoRoot (Get-Location).Path
}
if (-not $repoRoot) { throw "Repository root not found: no .git or .github in parent chain." }

# --- Load exclude policy and merge with args ---
$policy = Load-SliceExcludePolicy $repoRoot
if ($null -ne $policy) {
  if ($null -ne $policy.excludeDir) { $ExcludeDir = Merge-Unique $ExcludeDir $policy.excludeDir }
  if ($null -ne $policy.excludeExt) { $ExcludeExt = Merge-Unique $ExcludeExt $policy.excludeExt }
}

Assert-GitAvailable

# --- Collect delta ---
$delta = Get-GitDelta -repoRoot $repoRoot -baseRef $BaseRef -headRef $HeadRef

# Filter exclusions
$filtered = @()
foreach ($i in $delta) {
  if ($i.status -eq "D") {
    # Keep deletes even if excluded; deletion still matters for the model.
    $filtered += $i
    continue
  }
  if (Should-ExcludeRelPath $i.path) { continue }
  $filtered += $i
}

# --- Prepare output paths ---
$outAbs = Join-Path $repoRoot $OutDir
Ensure-Dir $outAbs

$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
if ([string]::IsNullOrWhiteSpace($ZipFile)) {
  $ZipFile = Join-Path $outAbs ("delta-slice-" + $stamp + ".zip")
} elseif (![System.IO.Path]::IsPathRooted($ZipFile)) {
  $ZipFile = Join-Path $repoRoot $ZipFile
}

$metaFile = Join-Path $outAbs ("slice-meta-" + $stamp + ".json")
$manifestFile = Join-Path $outAbs ("slice-manifest-" + $stamp + ".ndjson")
$mapFile = Join-Path $outAbs ("slice-map-" + $stamp + ".md")

# --- Write meta ---
$meta = [pscustomobject]@{
  mode = "delta"
  generatedAtUtc = $stamp
  baseRef = $BaseRef
  headRef = $HeadRef
  includeUntracked = [bool]$IncludeUntracked
  outDir = (Normalize-RelPath $OutDir)
}
($meta | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $metaFile -Encoding UTF8

# --- Create zip & manifest ---
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (Test-Path -LiteralPath $ZipFile) { Remove-Item -LiteralPath $ZipFile -Force }

$zip = [System.IO.Compression.ZipFile]::Open($ZipFile, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($i in $filtered) {
    $p = Normalize-RelPath $i.path
    if ($i.status -eq "D") {
      Write-NdjsonLine $manifestFile ([pscustomobject]@{ path=$p; status="D"; sha256=$null; size=$null; oldPath=$i.oldPath })
      continue
    }

    $abs = Join-Path $repoRoot $p
    if (!(Test-Path -LiteralPath $abs -PathType Leaf)) {
      Write-NdjsonLine $manifestFile ([pscustomobject]@{ path=$p; status=$i.status; sha256=$null; size=$null; oldPath=$i.oldPath; note="missing-on-disk" })
      continue
    }

    $h = (Get-FileHash -LiteralPath $abs -Algorithm SHA256).Hash.ToLowerInvariant()
    $size = (Get-Item -LiteralPath $abs).Length

    $added = Add-FileToZip -zipArchive $zip -repoRoot $repoRoot -relPath $p
    $note = $null
    if (-not $added) { $note = "zip-skip" }

    Write-NdjsonLine $manifestFile ([pscustomobject]@{ path=$p; status=$i.status; sha256=$h; size=$size; oldPath=$i.oldPath; note=$note })
  }
} finally {
  $zip.Dispose()
}

# --- Optional: write mini-map ---
if ($WriteMap) {
  $paths = @()
  foreach ($i in $filtered) {
    if ($i.status -eq "D") { continue }
    $paths += (Normalize-RelPath $i.path)
  }
  $paths = $paths | Sort-Object -Unique

  $lines = @()
  $lines += "# Slice map (delta)"
  $lines += ""
  $lines += ("baseRef: " + $BaseRef)
  $lines += ("headRef: " + $HeadRef)
  $lines += ("items: " + $paths.Count)
  $lines += ""
  foreach ($p in $paths) { $lines += ("- " + $p) }
  ($lines -join "`n") | Set-Content -LiteralPath $mapFile -Encoding UTF8
}

Write-Host ("OK: " + $ZipFile)
Write-Host ("meta: " + $metaFile)
Write-Host ("manifest: " + $manifestFile)
if ($WriteMap) { Write-Host ("map: " + $mapFile) }
