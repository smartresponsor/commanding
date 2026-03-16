@echo off
setlocal

cd /d "%~dp0"

set "GIT_BASH=C:\Program Files\Git\bin\bash.exe"
if not exist "%GIT_BASH%" set "GIT_BASH=C:\Program Files\Git\usr\bin\bash.exe"

if not exist "%GIT_BASH%" (
  echo Git Bash not found.
  echo Expected one of:
  echo   C:\Program Files\Git\bin\bash.exe
  echo   C:\Program Files\Git\usr\bin\bash.exe
  pause
  exit /b 1
)

"%GIT_BASH%" --login -i "%~dp0commanding.sh"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo.
  echo Commanding exited with code %EXIT_CODE%.
  pause
)

endlocal
exit /b %EXIT_CODE%
