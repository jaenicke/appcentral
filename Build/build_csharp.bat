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

REM NativeAOT braucht VS-Linker und vswhere.exe im PATH
set "PATH=C:\Program Files (x86)\Microsoft Visual Studio\Installer;%PATH%"
call "C:\Program Files\Microsoft Visual Studio\18\Professional\VC\Auxiliary\Build\vcvarsall.bat" x64 >NUL
if errorlevel 1 (
    echo FEHLER: vcvarsall.bat nicht gefunden
    exit /b 1
)

echo === Kompiliere C# DLL (NativeAOT, x64) ===
dotnet publish "%EXAMPLES%\CSharpDLL\ExampleCSharpDLL.csproj" ^
    -c Release -r win-x64 ^
    -o "%OUTPUT%\_csdll_publish"
if errorlevel 1 exit /b 1

REM Nur die DLL kopieren
copy /Y "%OUTPUT%\_csdll_publish\ExampleCSharpDLL.dll" "%OUTPUT%\" >NUL
rmdir /S /Q "%OUTPUT%\_csdll_publish"

echo.
echo === Kompiliere C# Host (x64) ===
dotnet publish "%EXAMPLES%\CSharpHost\CSharpHost.csproj" ^
    -c Release -r win-x64 --self-contained false ^
    -o "%OUTPUT%\_cshost_publish"
if errorlevel 1 exit /b 1

REM EXE und benoetigte runtime-Dateien kopieren
copy /Y "%OUTPUT%\_cshost_publish\CSharpHost.exe" "%OUTPUT%\" >NUL
copy /Y "%OUTPUT%\_cshost_publish\CSharpHost.dll" "%OUTPUT%\" >NUL
copy /Y "%OUTPUT%\_cshost_publish\CSharpHost.runtimeconfig.json" "%OUTPUT%\" >NUL
copy /Y "%OUTPUT%\_cshost_publish\CSharpHost.deps.json" "%OUTPUT%\" >NUL 2>NUL
rmdir /S /Q "%OUTPUT%\_cshost_publish"

echo.
echo === Fertig ===
dir /b "%OUTPUT%\CSharp*" "%OUTPUT%\ExampleCSharp*"
