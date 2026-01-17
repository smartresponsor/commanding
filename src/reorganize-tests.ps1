param([switch]$DryRun)

$repoRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$testsRoot = Join-Path $repoRoot "tests"

if (-not (Test-Path $testsRoot)) { throw "Не найдена папка tests: $testsRoot" }

# ===== СЛУЖЕБНЫЕ =====
$fixedByName = @(
@{ Pattern = '^.*FactoryTest\.php$'; Dest = 'Factory' },
@{ Pattern = '^(FactorySmokeTest|FactoriesIntegrationTest)\.php$'; Dest = 'Integration' },
@{ Pattern = '^(VerificationControllerTest|RouteCode200Test|OrderEmailManagerTest|EntityAttachmentTest)\.php$'; Dest = 'Functional' },
@{ Pattern = '^formAuthTest\.php$'; Dest = 'Unit' },
@{ Pattern = '^(BaseWebTestCase|BaseTestCase|BootKernelTest)\.php$'; Dest = 'Base' },
@{ Pattern = '^bootstrap\.php$'; Dest = 'Base' } # bootstrap не неймспейсим
)

# Доменные подпапки, которые сохраняем как есть
$keepSubdirs = @('Api','DTO','E2E','Form','Twig','Stub','Vendor')

# Нормализация имён «временных» папок
$normalizeDirs = @{
    'temp' = 'Temp'
    'test' = 'Test'
}

function Get-Rel {
    param($full)
    ($full.Substring($testsRoot.Length)).TrimStart('\','/')
}

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) {
        if ($DryRun) { Write-Host "[DRY] MKDIR $path"; return }
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

function Move-File($src, $dst) {
    Ensure-Dir (Split-Path -Parent $dst)
    if ($src -ieq $dst) { return }
    if ($DryRun) { Write-Host "[DRY] MOVE $src -> $dst"; return }
    Move-Item -Force -Path $src -Destination $dst
    Write-Host "Moved $src -> $dst"
}

function Update-Namespace($filePath, $ns, $skip = $false) {
    if ($skip) { return }
    $content = Get-Content $filePath -Raw

    # bootstrap.php не трогаем
    if ([IO.Path]::GetFileName($filePath) -ieq 'bootstrap.php') { return }

    $decl = 'declare(strict_types=1);'
    $hasNs = $content -match '^\s*namespace\s+[A-Za-z0-9_\\]+;\s*$' -im
    if ($hasNs) {
        $content = [regex]::Replace($content, '^\s*namespace\s+[A-Za-z0-9_\\]+;\s*$', "namespace $ns;", 'IgnoreCase, Multiline')
    } else {
        if ($content -match '^\s*<\?php') {
            if ($content -match [regex]::Escape($decl)) {
                $content = $content -replace "($decl\s*)", "`$1`r`nnamespace $ns;`r`n"
            } else {
                $content = $content -replace '^\s*<\?php\s*', "<?php`r`nnamespace $ns;`r`n"
            }
        } else {
            $content = "<?php`r`nnamespace $ns;`r`n" + $content
        }
    }

    if ($DryRun) { Write-Host "[DRY] NS  $filePath -> $ns"; return }
    Set-Content -Path $filePath -Value $content -Encoding UTF8
}

function Rel-To-Namespace($relPath) {
    # relPath: like "\Vendor\VendorEnTest.php" or "\DTO\X\YTest.php"
    $dir = Split-Path $relPath -Parent
    if ([string]::IsNullOrWhiteSpace($dir)) { return 'App\Tests' }

    # Преобразуем \ -> \\ для namespace
    $parts = $dir.Trim('\','/').Split('\','/').Where({$_ -ne ''})
    if ($parts.Count -eq 0) { return 'App\Tests' }
    return 'App\Tests\' + ($parts -join '\')
}

# Нормализуем «temp/test» -> «Temp/Test»
Get-ChildItem -Recurse -Directory -Path $testsRoot | ForEach-Object {
    $name = $_.Name
    if ($normalizeDirs.ContainsKey($name)) {
        $dst = Join-Path ($_.Parent.FullName) $normalizeDirs[$name]
        if ($_.FullName -ne $dst) { Move-File $_.FullName $dst }
    }
}

# Собираем файлы
$files = Get-ChildItem -Recurse -Path $testsRoot -File -Include *.php

foreach ($f in $files) {
    $rel = Get-Rel $f.FullName
    $name = $f.Name

    # 1) bootstrap — спец.случай
    if ($name -ieq 'bootstrap.php') {
        $dst = Join-Path (Join-Path $testsRoot 'Base') $name
        Move-File $f.FullName $dst
        continue
    }

    # 2) Доменные подпапки (оставляем в них, только NS)
    $kept = $false
    foreach ($k in $keepSubdirs) {
        if ($rel -match ("(^|\\|/)" + [regex]::Escape($k) + "(\\|/|$)")) {
            $ns = Rel-To-Namespace $rel
            Update-Namespace ($f.FullName) $ns
            $kept = $true
            break
        }
    }
    if ($kept) { continue }

    # 3) Сопоставление по имени — переносим в целевую папку tests\<Dest>
    $destHit = $null
    foreach ($rule in $fixedByName) {
        if ($name -match $rule.Pattern) { $destHit = $rule; break }
    }

    if ($null -ne $destHit) {
        $destDir = Join-Path $testsRoot $destHit.Dest
        $dst = Join-Path $destDir $name
        Move-File $f.FullName $dst
        $ns = "App\Tests\" + $destHit.Dest
        $skipNs = ($name -ieq 'bootstrap.php') # на всякий случай
        Update-Namespace $dst $ns $skipNs
        continue
    }

    # 4) Иначе — оставляем текущую относительную папку, но если файл лежит прямо в корне tests — НЕ трогаем путь
    $dirRel = Split-Path $rel -Parent
    if ($dirRel -eq '') {
        # файл в корне tests -> только NS "App\Tests"
        Update-Namespace $f.FullName 'App\Tests'
    } else {
        # перенесём на верхний уровень tests\<TopLevel>\<File>, если это было tests\temp\* или tests\test\*
        $top = $dirRel.Split('\','/')[0]
        if ($normalizeDirs.ContainsValue($top)) {
            $destDir = Join-Path $testsRoot $top
            $dst = Join-Path $destDir $name
            Move-File $f.FullName $dst
            $ns = "App\Tests\$top"
            Update-Namespace $dst $ns
        } else {
            # в прочих нестандартных подпапках — просто нормализуем NS по пути
            $ns = Rel-To-Namespace $rel
            Update-Namespace $f.FullName $ns
        }
    }
}

# Удалим пустые папки внутри tests
Get-ChildItem -Recurse -Path $testsRoot -Directory |
        Sort-Object FullName -Descending | ForEach-Object {
    if (-not (Get-ChildItem -Force $_.FullName)) {
        if ($DryRun) { Write-Host "[DRY] RMDIR $($_.FullName)" }
        else { Remove-Item $_.FullName -Force }
    }
}

# Подсказка по окружению
if (-not (Test-Path (Join-Path $repoRoot 'vendor\autoload.php'))) {
    Write-Warning "vendor\autoload.php не найден. Выполни в корне:
    composer install
    composer dump-autoload -o"
}
