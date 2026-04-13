@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "INSTALLER=%SCRIPT_DIR%install.py"
set "CONFIG=%~1"
if "%CONFIG%"=="" set "CONFIG=.\project.config.json"

if not exist "%INSTALLER%" (
  echo ERROR: install.py not found: %INSTALLER%
  exit /b 1
)

where py >nul 2>nul
if %errorlevel%==0 (
  py -3 "%INSTALLER%" "%CONFIG%" %2 %3 %4 %5 %6 %7 %8 %9
  exit /b %errorlevel%
)

where python >nul 2>nul
if %errorlevel%==0 (
  python "%INSTALLER%" "%CONFIG%" %2 %3 %4 %5 %6 %7 %8 %9
  exit /b %errorlevel%
)

echo ERROR: Python 3 is required. Install Python and retry.
exit /b 1

