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

REM --- Menu path inside repo (POSIX style for bash) ---
set "COMMANDING_POSIX=./commanding.sh"
if not "%~2"=="" set "COMMANDING_POSIX=%~2"

REM --- Detect Windows Terminal ---
set "HAS_WT=0"
where wt.exe >nul 2>nul && set "HAS_WT=1"

REM --- Detect Git Bash (preferred) ---
set "BASH_EXE="
for %%P in (
  "%ProgramFiles%\Git\bin\bash.exe"
  "%ProgramFiles%\Git\usr\bin\bash.exe"
  "%ProgramW6432%\Git\bin\bash.exe"
  "%ProgramW6432%\Git\usr\bin\bash.exe"
  "%LocalAppData%\Programs\Git\bin\bash.exe"
  "%LocalAppData%\Programs\Git\usr\bin\bash.exe"
) do (
  if not defined BASH_EXE if exist "%%~P" set "BASH_EXE=%%~P"
)

REM --- Detect WSL fallback ---
set "HAS_WSL=0"
where wsl.exe >nul 2>nul && set "HAS_WSL=1"

REM --- Command inside bash: run commanding (if exists) then keep interactive ---
set "BASH_CMD=if [ -f %COMMANDING_POSIX% ]; then bash %COMMANDING_POSIX%; fi; exec bash -i"

REM =========================
REM 1) Git Bash path found
REM =========================
if defined BASH_EXE (
  if "%HAS_WT%"=="1" (
    wt -w 0 new-tab --title "%REPO_NAME%" -d "%REPO_DIR%" "%BASH_EXE%" -lc "%BASH_CMD%"
    exit /b 0
  ) else (
    start "" "%BASH_EXE%" -lc "%BASH_CMD%"
    exit /b 0
  )
)

REM =========================
REM 2) WSL fallback
REM =========================
if "%HAS_WSL%"=="1" (
  if "%HAS_WT%"=="1" (
    wt -w 0 new-tab --title "%REPO_NAME%" wsl.exe -- bash -lc "cd \"$(wslpath -a '%REPO_DIR%')\"; %BASH_CMD%"
    exit /b 0
  ) else (
    start "" wsl.exe -- bash -lc "cd \"$(wslpath -a '%REPO_DIR%')\"; %BASH_CMD%"
    exit /b 0
  )
)

echo ERROR: No bash found.
echo Install Git for Windows (preferred) or enable WSL.
exit /b 1
