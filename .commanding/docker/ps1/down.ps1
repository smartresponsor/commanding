# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DockerDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot '_lib.ps1')

$Stack = if ($args.Count -ge 1) { $args[0] } else { 'db' }

$RepoRoot = Get-RepoRoot -StartDir $DockerDir
Export-Defaults -RepoRoot $RepoRoot

$cmd = Get-ComposeCommand

function Invoke-StackDown([string]$s) {
  $files = Get-ComposeFileList -Stack $s -DockerDir $DockerDir -RepoRoot $RepoRoot
  $composeArgs = @()
  foreach ($f in $files) { $composeArgs += @('-f', $f) }

  try {
    & $cmd @composeArgs down --remove-orphans
  } catch {
    # ignore
  }
}

if ($Stack -eq 'all') {
  Invoke-StackDown 'obs'
  Invoke-StackDown 'object'
  Invoke-StackDown 'mq'
  Invoke-StackDown 'cache'
  Invoke-StackDown 'db'
  exit 0
}

Invoke-StackDown $Stack
