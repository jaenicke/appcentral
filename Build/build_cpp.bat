@echo off
setlocal
set "BUILD=%~dp0"
set "ROOT=%BUILD%.."
set "OUTPUT=%ROOT%\Output"
set "EXAMPLES=%ROOT%\Examples"
if not exist "%OUTPUT%" mkdir "%OUTPUT%"

call "C:\Program Files\Microsoft Visual Studio\18\Professional\VC\Auxiliary\Build\vcvarsall.bat" x64

echo.
echo === Kompiliere C++ DLL (x64) ===
cd /d "%OUTPUT%"
cl /nologo /LD /EHsc /std:c++17 /O2 "%EXAMPLES%\CppDLL\ExampleCppDLL.cpp" ole32.lib oleaut32.lib /Fe:ExampleCppDLL.dll
if errorlevel 1 (
    echo FEHLER beim Kompilieren der DLL
    exit /b 1
)

echo.
echo === Kompiliere C++ Host (x64) ===
cl /nologo /EHsc /std:c++17 /O2 "%EXAMPLES%\CppHost\main.cpp" ole32.lib oleaut32.lib /Fe:CppHost.exe
if errorlevel 1 (
    echo FEHLER beim Kompilieren des Hosts
    exit /b 1
)

REM Build-Artefakte aufraeumen
del /q *.obj *.exp *.lib 2>NUL

echo.
echo === Fertig ===
dir /b *.dll *.exe
