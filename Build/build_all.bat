@echo off
REM Builds all components. Components without their toolchain get skipped.
setlocal

set BUILD=%~dp0

echo ##############################################
echo  Building all AppCentral components
echo ##############################################

call "%BUILD%build_cpp.bat" || echo [SKIP] C++
echo.
call "%BUILD%build_delphi.bat" || echo [SKIP] Delphi
echo.
call "%BUILD%build_delphi_java.bat" || echo [SKIP] DelphiJavaHost
echo.
call "%BUILD%build_csharp.bat" || echo [SKIP] C#
echo.
call "%BUILD%build_csharp_auto.bat" || echo [SKIP] C# Auto
echo.
call "%BUILD%build_dotnet_hosts.bat" || echo [SKIP] VB.NET / F#
echo.
call "%BUILD%build_rust.bat" || echo [SKIP] Rust
echo.
call "%BUILD%build_freepascal.bat" || echo [SKIP] FreePascal
echo.
call "%BUILD%build_java_dll.bat" || echo [SKIP] Java DLL
echo.
call "%BUILD%build_java_host.bat" || echo [SKIP] Java Host

echo.
echo ##############################################
echo  Done
echo ##############################################
dir /b "C:\Beispiele\AppCentral\Output\*.exe" "C:\Beispiele\AppCentral\Output\*.dll"
