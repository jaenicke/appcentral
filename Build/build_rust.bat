@echo off
setlocal
set "BUILD=%~dp0"
set "ROOT=%BUILD%.."
set "OUTPUT=%ROOT%\Output"
set "EXAMPLES=%ROOT%\Examples"
if not exist "%OUTPUT%" mkdir "%OUTPUT%"
set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"

call "C:\Program Files\Microsoft Visual Studio\18\Professional\VC\Auxiliary\Build\vcvarsall.bat" x64 >NUL

echo === Kompiliere Rust DLL ===
cd /d %EXAMPLES%\RustDLL
cargo build --release --target x86_64-pc-windows-msvc
if errorlevel 1 exit /b 1
copy /Y "target\x86_64-pc-windows-msvc\release\ExampleRustDLL.dll" "%OUTPUT%\" >NUL

echo.
echo === Kompiliere Rust Host ===
cd /d %EXAMPLES%\RustHost
cargo build --release --target x86_64-pc-windows-msvc
if errorlevel 1 exit /b 1
copy /Y "target\x86_64-pc-windows-msvc\release\RustHost.exe" "%OUTPUT%\" >NUL

echo.
echo === Fertig ===
dir /b "%OUTPUT%\RustHost.exe" "%OUTPUT%\ExampleRustDLL.dll"
