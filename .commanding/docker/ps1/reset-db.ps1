# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DockerDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot '_lib.ps1')

$RepoRoot = Get-RepoRoot -StartDir $DockerDir
Export-Defaults -RepoRoot $RepoRoot

$cmd = Get-ComposeCommand

$files = Get-ComposeFileList -Stack 'db' -DockerDir $DockerDir -RepoRoot $RepoRoot
$composeArgs = @()
foreach ($f in $files) { $composeArgs += @('-f', $f) }

& $cmd @composeArgs down -v --remove-orphans
& $cmd @composeArgs up -d --remove-orphans
