@echo off
setlocal

set OUTPUT=C:\Beispiele\AppCentral\Output
if not exist "%OUTPUT%" mkdir "%OUTPUT%"
set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"

call "C:\Program Files\Microsoft Visual Studio\18\Professional\VC\Auxiliary\Build\vcvarsall.bat" x64 >NUL

echo === Kompiliere Rust DLL ===
cd /d C:\Beispiele\AppCentral\Examples\RustDLL
cargo build --release --target x86_64-pc-windows-msvc
if errorlevel 1 exit /b 1
copy /Y "target\x86_64-pc-windows-msvc\release\ExampleRustDLL.dll" "%OUTPUT%\" >NUL

echo.
echo === Kompiliere Rust Host ===
cd /d C:\Beispiele\AppCentral\Examples\RustHost
cargo build --release --target x86_64-pc-windows-msvc
if errorlevel 1 exit /b 1
copy /Y "target\x86_64-pc-windows-msvc\release\RustHost.exe" "%OUTPUT%\" >NUL

echo.
echo === Fertig ===
dir /b "%OUTPUT%\RustHost.exe" "%OUTPUT%\ExampleRustDLL.dll"
