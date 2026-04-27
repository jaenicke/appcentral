@echo off
setlocal
set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot"
set "PATH=%JAVA_HOME%\bin\server;%JAVA_HOME%\bin;%PATH%"

set OUTPUT=C:\Beispiele\AppCentral\Output

REM Alle DLLs zum Testen (nicht alle muessen vorhanden sein)
set DLLS=ExampleCppDLL.dll ExampleDelphiDLL.dll ExampleJavaDLL.dll ExampleCSharpDLL.dll ExampleCSharpDLLAuto.dll ExampleRustDLL.dll ExampleFPCDLL.dll

call :TestHost "C++ Host"      "%OUTPUT%\CppHost.exe"
call :TestHost "Delphi Host"   "%OUTPUT%\DelphiHost.exe"
call :TestHost "C# Host"       "%OUTPUT%\CSharpHost.exe"
call :TestHost "VB.NET Host"   "%OUTPUT%\VBNetHost.exe"
call :TestHost "F# Host"       "%OUTPUT%\FSharpHost.exe"
call :TestHost "Rust Host"     "%OUTPUT%\RustHost.exe"
if exist "%OUTPUT%\FPCHost.exe" call :TestHost "FreePascal Host" "%OUTPUT%\FPCHost.exe"
call :TestJavaHost
call :TestPythonHost
call :TestPowerShellHost

echo.
echo ==============================================
echo === Alle Tests fertig                      ===
echo ==============================================
goto :eof

:TestHost
echo.
echo ==============================================
echo === %~1
echo ==============================================
for %%D in (%DLLS%) do (
    if exist "%OUTPUT%\%%D" (
        echo.
        echo --- %~1 + %%D ---
        pushd "%OUTPUT%"
        echo. | "%~2" %%D
        popd
    )
)
goto :eof

:TestJavaHost
echo.
echo ==============================================
echo === Java Host
echo ==============================================
for %%D in (%DLLS%) do (
    if exist "%OUTPUT%\%%D" (
        echo.
        echo --- Java Host + %%D ---
        java --enable-native-access=ALL-UNNAMED -cp "%OUTPUT%;%OUTPUT%\jna-5.14.0.jar;%OUTPUT%\jna-platform-5.14.0.jar" Main "%OUTPUT%\%%D" 2>nul
    )
)
goto :eof

:TestPythonHost
echo.
echo ==============================================
echo === Python Host
echo ==============================================
for %%D in (%DLLS%) do (
    if exist "%OUTPUT%\%%D" (
        echo.
        echo --- Python Host + %%D ---
        pushd C:\Beispiele\AppCentral\Examples\PythonHost
        python -u main.py "%OUTPUT%\%%D"
        popd
    )
)
goto :eof

:TestPowerShellHost
echo.
echo ==============================================
echo === PowerShell Host
echo ==============================================
for %%D in (%DLLS%) do (
    if exist "%OUTPUT%\%%D" (
        echo.
        echo --- PowerShell Host + %%D ---
        powershell -NoProfile -ExecutionPolicy Bypass -File C:\Beispiele\AppCentral\Examples\PowerShellHost\main.ps1 -DllPath "%OUTPUT%\%%D"
    )
)
goto :eof
