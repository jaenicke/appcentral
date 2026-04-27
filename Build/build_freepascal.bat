@echo off
setlocal
set "BUILD=%~dp0"
set "ROOT=%BUILD%.."
set "OUTPUT=%ROOT%\Output"
set "EXAMPLES=%ROOT%\Examples"
if not exist "%OUTPUT%" mkdir "%OUTPUT%"

REM On Lazarus 4.0 for Win64 only i386-win32 is shipped by default.
REM Note: 32-bit FPC binaries can only interop with other 32-bit builds.
if exist "C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe" (
    set "FPC=C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe"
    set FPC_ARCH=x64
) else if exist "C:\lazarus\fpc\3.2.2\bin\i386-win32\fpc.exe" (
    set "FPC=C:\lazarus\fpc\3.2.2\bin\i386-win32\fpc.exe"
    set FPC_ARCH=x86
    echo NOTE: Only 32-bit FPC available - output is 32-bit
) else (
    echo ERROR: FreePascal not found in C:\lazarus
    exit /b 1
)

REM Suppress FPC RTL generics-collection noise:
REM   06058 - Call to inline subroutine not inlined (hint)
REM   04046 - Constructing a class with abstract method (FPC RTL internals)
REM   05024 - Parameter is not used (inside generics.collections)
REM   05071 - Private type ... never used (inside generics.collections)
set "VM=-vm6058 -vm4046 -vm5024 -vm5071"

echo === Building FreePascal DLL (%FPC_ARCH%) ===
cd /d %EXAMPLES%\FreePascalDLL
"%FPC%" -O2 -B %VM% -FE"%OUTPUT%" -FU. -Fu..\.. -Fu.. ExampleFPCDLL.lpr
if errorlevel 1 exit /b 1
del /q *.o *.ppu *.lib 2>NUL

echo.
echo === Building FreePascal Host (%FPC_ARCH%) ===
cd /d %EXAMPLES%\FreePascalHost
"%FPC%" -O2 -B %VM% -FE"%OUTPUT%" -FU. -Fu..\.. -Fu.. FPCHost.lpr
if errorlevel 1 exit /b 1
del /q *.o *.ppu 2>NUL

echo.
echo === Done ===
dir /b "%OUTPUT%\FPCHost.exe" "%OUTPUT%\ExampleFPCDLL.dll"
