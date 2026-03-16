# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DockerDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot '_lib.ps1')

$Stack = if ($args.Count -ge 1) { $args[0] } else { 'db' }

$RepoRoot = Get-RepoRoot -StartDir $DockerDir
Export-Defaults -RepoRoot $RepoRoot

$cmd = Get-ComposeCommand

function Invoke-StackUp([string]$s) {
  $files = Get-ComposeFileList -Stack $s -DockerDir $DockerDir -RepoRoot $RepoRoot
  $composeArgs = @()
  foreach ($f in $files) { $composeArgs += @('-f', $f) }

  & $cmd @composeArgs up -d --remove-orphans
}

if ($Stack -eq 'all') {
  Invoke-StackUp 'db'
  Invoke-StackUp 'cache'
  Invoke-StackUp 'mq'
  Invoke-StackUp 'object'
  Invoke-StackUp 'obs'
  exit 0
}

Invoke-StackUp $Stack
