@echo off
setlocal
set "BUILD=%~dp0"
set "ROOT=%BUILD%.."
set "OUTPUT=%ROOT%\Output"
set "EXAMPLES=%ROOT%\Examples"
set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot"
set "PATH=%JAVA_HOME%\bin\server;%JAVA_HOME%\bin;%PATH%"
echo ========================================================
echo Test: Plugin-zu-Plugin-Routing via Host (FromHost-Flag)
echo ========================================================
echo.
echo --- DelphiHost + Delphi + C++ ---
pushd "%OUTPUT%"
echo. | "%OUTPUT%\DelphiHost.exe" ExampleDelphiDLL.dll ExampleCppDLL.dll
echo.
echo --- DelphiHost + Java + C# ---
echo. | "%OUTPUT%\DelphiHost.exe" ExampleJavaDLL.dll ExampleCSharpDLLAuto.dll
popd
