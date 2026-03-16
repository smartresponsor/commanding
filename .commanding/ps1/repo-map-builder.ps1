param(
  [string]$Root = ".",
  [string]$OutFile = "repo-map.md",
  [int]$MaxDepth = 12,

  # Folder names to skip anywhere in the tree
  [string[]]$ExcludeDir = @(
    ".git", ".idea", ".vscode", "bin",
    "vendor", "node_modules",
    ".next", "dist", "build", "coverage",
    "var", "cache", "tmp", "temp", ".tmp", ".temp",
    ".cache", ".turbo",
    "logs", "log", ".gate", ".gating", ".commanding",
    ".consuming", ".intelligence", ".release", ".smoke", ".canonization", ".dist"
  ),

  # Optional: skip files by extension
  [string[]]$ExcludeExt = @(
    ".log", ".tmp", ".cache"
  ),

  # Optional: show files too (true), or only folders (false)
  [switch]$IncludeFiles = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-Root([string]$p) {
  $full = (Resolve-Path -LiteralPath $p).Path
  return $full.TrimEnd('\','/')
}

$rootPath = Normalize-Root $Root
$excludeDirSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($d in $ExcludeDir) { [void]$excludeDirSet.Add($d) }

$excludeExtSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($e in $ExcludeExt) { [void]$excludeExtSet.Add($e) }

function Is-ExcludedDir([string]$name) {
  return $excludeDirSet.Contains($name)
}

function Is-ExcludedFile([string]$path) {
  $ext = [System.IO.Path]::GetExtension($path)
  if ([string]::IsNullOrWhiteSpace($ext)) { return $false }
  return $excludeExtSet.Contains($ext)
}

function Get-Relative([string]$fullPath) {
  if ($fullPath.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)) {
    $rel = $fullPath.Substring($rootPath.Length).TrimStart('\','/')
    if ([string]::IsNullOrEmpty($rel)) { return "." }
    return $rel -replace '\\','/'
  }
  return $fullPath -replace '\\','/'
}

function Walk([string]$dir, [int]$depth, [System.Collections.Generic.List[string]]$lines) {
  if ($depth -gt $MaxDepth) { return }

  $items = Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop |
    Where-Object {
      if ($_.PSIsContainer) { return -not (Is-ExcludedDir $_.Name) }
      if (-not $IncludeFiles) { return $false }
      return -not (Is-ExcludedFile $_.FullName)
    } |
    Sort-Object @{Expression={ -not $_.PSIsContainer }}, Name  # folders first

  foreach ($item in $items) {
    $rel = Get-Relative $item.FullName
    $indent = "  " * $depth
    if ($item.PSIsContainer) {
      $lines.Add("$indent$rel/")
      Walk $item.FullName ($depth + 1) $lines
    } else {
      $lines.Add("$indent$rel")
    }
  }
}

# Header
$lines = New-Object 'System.Collections.Generic.List[string]'
$lines.Add("REPO MAP")
$lines.Add("root: $((Get-Relative $rootPath))")
try {
  $gitRoot = (& git rev-parse --show-toplevel 2>$null).Trim()
  if ($gitRoot) {
    $sha = (& git rev-parse HEAD 2>$null).Trim()
    $branch = (& git rev-parse --abbrev-ref HEAD 2>$null).Trim()
    if ($sha) { $lines.Add("git: $branch @ $sha") }
  }
} catch {}
$lines.Add("generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")")
$lines.Add("excludeDir: $($ExcludeDir -join ', ')")
$lines.Add("excludeExt: $($ExcludeExt -join ', ')")
$lines.Add("maxDepth: $MaxDepth")
$lines.Add("")
$lines.Add("TREE")
$lines.Add(".")

Walk $rootPath 1 $lines

# Write as UTF-8 without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines((Resolve-Path -LiteralPath (Split-Path -Parent $OutFile) -ErrorAction SilentlyContinue ?? ".").Path + "\" + (Split-Path -Leaf $OutFile), $lines, $utf8NoBom)

Write-Host "OK: wrote $OutFile"
