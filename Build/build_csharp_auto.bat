@echo off
setlocal
set "BUILD=%~dp0"
set "ROOT=%BUILD%.."
set "OUTPUT=%ROOT%\Output"
set "EXAMPLES=%ROOT%\Examples"
if not exist "%OUTPUT%" mkdir "%OUTPUT%"

where dotnet >NUL 2>&1
if errorlevel 1 (
    echo FEHLER: dotnet nicht gefunden.
    exit /b 1
)

set "PATH=C:\Program Files (x86)\Microsoft Visual Studio\Installer;%PATH%"
call "C:\Program Files\Microsoft Visual Studio\18\Professional\VC\Auxiliary\Build\vcvarsall.bat" x64 >NUL
if errorlevel 1 (
    echo FEHLER: vcvarsall.bat nicht gefunden
    exit /b 1
)

echo === Kompiliere C# DLL Auto (deklarativ via [GeneratedComClass]) ===
dotnet publish "%EXAMPLES%\CSharpDLLAuto\ExampleCSharpDLLAuto.csproj" ^
    -c Release -r win-x64 ^
    -o "%OUTPUT%\_csautodll_publish"
if errorlevel 1 exit /b 1

copy /Y "%OUTPUT%\_csautodll_publish\ExampleCSharpDLLAuto.dll" "%OUTPUT%\" >NUL
rmdir /S /Q "%OUTPUT%\_csautodll_publish"

echo.
echo === Fertig ===
dir /b "%OUTPUT%\ExampleCSharpDLLAuto.dll"
