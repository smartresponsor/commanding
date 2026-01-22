REM --- Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp ---
@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM --- Resolve repo dir ---
set "REPO_DIR="
if not "%~1"=="" (
  for %%I in ("%~1") do set "REPO_DIR=%%~fI"
) else (
  REM assumes this file lives in <repo>\.commanding\
  for %%I in ("%~dp0..") do set "REPO_DIR=%%~fI"
)

for %%I in ("%REPO_DIR%") do set "REPO_NAME=%%~nI"

REM --- Default menu entry inside repo ---
set "COMMANDING_SH=.commanding/commanding.sh"
if not "%~2"=="" set "COMMANDING_SH=%~2"

REM --- Detect Windows Terminal ---
set "WT=0"
where wt.exe >nul 2>nul && set "WT=1"

REM --- Detect Git Bash (preferred) ---
set "BASH="
for %%P in (
  "%ProgramFiles%\Git\bin\bash.exe"
  "%ProgramFiles%\Git\usr\bin\bash.exe"
  "%ProgramW6432%\Git\bin\bash.exe"
  "%ProgramW6432%\Git\usr\bin\bash.exe"
  "%LocalAppData%\Programs\Git\bin\bash.exe"
  "%LocalAppData%\Programs\Git\usr\bin\bash.exe"
) do (
  if not defined BASH if exist "%%~P" set "BASH=%%~P"
)

REM --- Detect WSL fallback ---
set "WSL=0"
where wsl.exe >nul 2>nul && set "WSL=1"

REM --- Command inside bash: start a single interactive bash that runs the menu ---
REM Notes:
REM  - "bash -i <script>" runs the script and then stays interactive in the SAME process
REM  - This removes the "first shell then exec bash" double-hop
set "BASH_CMD=if [ -f %COMMANDING_SH% ]; then exec bash -i %COMMANDING_SH%; else exec bash -i; fi"

REM =========================
REM 1) Git Bash path found
REM =========================
if defined BASH (
  if "%WT%"=="1" (
    REM Use "start /min" to avoid black flash on double-click
    start "" /min wt -w 0 new-tab --title "%REPO_NAME%" -d "%REPO_DIR%" -- "%BASH%" -lc "%BASH_CMD%" >nul 2>nul
    exit /b 0
  ) else (
    start "" /D "%REPO_DIR%" "%BASH%" -lc "%BASH_CMD%"
    exit /b 0
  )
)

REM =========================
REM 2) WSL fallback
REM =========================
if "%WSL%"=="1" (
  if "%WT%"=="1" (
    start "" /min wt -w 0 new-tab --title "%REPO_NAME%" wsl.exe -- bash -lc "cd \"$(wslpath -a '%REPO_DIR%')\"; %BASH_CMD%"
    exit /b 0
  ) else (
    start "" wsl.exe -- bash -lc "cd \"$(wslpath -a '%REPO_DIR%')\"; %BASH_CMD%"
    exit /b 0
  )
)

echo ERROR: No terminal found.
echo Install Git for Windows (preferred) or enable WSL.
exit /b 1
