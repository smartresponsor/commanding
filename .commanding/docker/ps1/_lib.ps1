# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
  param([string]$StartDir)

  $d = (Resolve-Path $StartDir).Path
  while ($true) {
    $name = Split-Path -Leaf $d
    if ($name -eq '.commanding') {
      return (Split-Path -Parent $d)
    }

    $parent = Split-Path -Parent $d
    if ($parent -eq $d -or [string]::IsNullOrWhiteSpace($parent)) {
      break
    }
    $d = $parent
  }

  return (Resolve-Path (Join-Path $StartDir '..\..')).Path
}

function Sanitize-Project([string]$Name) {
  $s = $Name.ToLowerInvariant()
  $s = ($s -replace '[^a-z0-9]+','-').Trim('-')
  if ([string]::IsNullOrWhiteSpace($s)) { $s = 'sr' }
  return $s
}

function Get-ComposeCommand {
  try {
    docker compose version | Out-Null
    return @('docker','compose')
  } catch {
    return @('docker-compose')
  }
}

function Get-ComposeFileList([string]$Stack, [string]$DockerDir, [string]$RepoRoot) {
  $base = Join-Path $DockerDir (Join-Path 'compose' ("compose-$Stack.yml"))
  if (-not (Test-Path $base)) {
    throw "Missing base compose: $base"
  }

  $list = New-Object System.Collections.Generic.List[string]
  $list.Add($base)

  $ov = Join-Path $RepoRoot (Join-Path 'deploy\docker' ("compose-$Stack.override.yml"))
  if (Test-Path $ov) { $list.Add($ov) }

  $ovAll = Join-Path $RepoRoot 'deploy\docker\compose.override.yml'
  if (Test-Path $ovAll) { $list.Add($ovAll) }

  return $list
}

function Export-Defaults([string]$RepoRoot) {
  if (-not $env:SR_COMPOSE_PROJECT) {
    $base = Split-Path -Leaf $RepoRoot
    $env:SR_COMPOSE_PROJECT = Sanitize-Project $base
  }
  $env:COMPOSE_PROJECT_NAME = $env:SR_COMPOSE_PROJECT
}
