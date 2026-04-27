@echo off
setlocal
set "BUILD=%~dp0"
set "ROOT=%BUILD%.."
set "OUTPUT=%ROOT%\Output"
set "EXAMPLES=%ROOT%\Examples"
if not exist "%OUTPUT%" mkdir "%OUTPUT%"

set "DCC=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe"
if not exist "%DCC%" goto :no_dcc
goto :have_dcc
:no_dcc
echo ERROR: dcc64.exe not found: %DCC%
exit /b 1
:have_dcc

REM RAD Studio directory for system units
set "BDS=C:\Program Files (x86)\Embarcadero\Studio\37.0"

REM Path containing AppCentral.pas + AppCentral.JNI.pas (root) + Examples\Interfaces.pas
set "UNITS=%BDS%\lib\Win64\release;%ROOT%;%EXAMPLES%"

cd /d %EXAMPLES%

echo === Building Delphi DLL (Win64) ===
"%DCC%" -B -Q ^
    -E"%OUTPUT%" ^
    -N"%OUTPUT%" ^
    -U"%UNITS%" ^
    -I"%UNITS%" ^
    -O"%UNITS%" ^
    -R"%UNITS%" ^
    DelphiDLL\ExampleDelphiDLL.dpr
if errorlevel 1 exit /b 1

echo.
echo === Building Delphi Host (Win64) ===
"%DCC%" -B -Q ^
    -E"%OUTPUT%" ^
    -N"%OUTPUT%" ^
    -U"%UNITS%" ^
    -I"%UNITS%" ^
    -O"%UNITS%" ^
    -R"%UNITS%" ^
    DelphiHost\DelphiHost.dpr
if errorlevel 1 exit /b 1

REM Clean up build artefacts
del /q "%OUTPUT%\*.dcu" 2>NUL
del /q *.dcu 2>NUL

echo.
echo === Done ===
dir /b "%OUTPUT%\Delphi*" "%OUTPUT%\ExampleDelphi*"
