@echo off
setlocal

set OUTPUT=C:\Beispiele\AppCentral\Output
if not exist "%OUTPUT%" mkdir "%OUTPUT%"

set "DCC=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe"
if not exist "%DCC%" goto :no_dcc
goto :have_dcc
:no_dcc
echo ERROR: dcc64.exe not found: %DCC%
exit /b 1
:have_dcc

set "BDS=C:\Program Files (x86)\Embarcadero\Studio\37.0"

REM Search paths: AppCentral.pas + AppCentral.JNI.pas at root, Interfaces.pas under Examples
set "UNITS=%BDS%\lib\Win64\release;C:\Beispiele\AppCentral;C:\Beispiele\AppCentral\Examples"

cd /d C:\Beispiele\AppCentral\Examples

echo === Building DelphiJavaHost (Win64) ===
"%DCC%" -B -Q ^
    -E"%OUTPUT%" ^
    -N"%OUTPUT%" ^
    -U"%UNITS%" ^
    -I"%UNITS%" ^
    -O"%UNITS%" ^
    -R"%UNITS%" ^
    DelphiJavaHost\DelphiJavaHost.dpr
if errorlevel 1 exit /b 1

del /q "%OUTPUT%\*.dcu" 2>NUL
del /q *.dcu 2>NUL

echo.
echo === Done ===
dir /b "%OUTPUT%\DelphiJavaHost.exe"
