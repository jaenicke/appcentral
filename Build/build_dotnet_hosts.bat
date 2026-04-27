@echo off
setlocal

set OUTPUT=C:\Beispiele\AppCentral\Output
if not exist "%OUTPUT%" mkdir "%OUTPUT%"

REM Clean up the old central AppCentralLibrary.dll if it's lingering from
REM previous builds - the per-host AppCentralLib.dll has replaced it.
del /q "%OUTPUT%\AppCentralLibrary.dll" 2>NUL

echo === Building VB.NET host ===
dotnet publish "C:\Beispiele\AppCentral\Examples\VBNetHost\VBNetHost.vbproj" ^
    -c Release -r win-x64 --self-contained false ^
    -o "%OUTPUT%\_vbhost_publish"
if errorlevel 1 exit /b 1

copy /Y "%OUTPUT%\_vbhost_publish\VBNetHost.exe" "%OUTPUT%\" >NUL
copy /Y "%OUTPUT%\_vbhost_publish\VBNetHost.dll" "%OUTPUT%\" >NUL
copy /Y "%OUTPUT%\_vbhost_publish\VBNetHost.runtimeconfig.json" "%OUTPUT%\" >NUL
copy /Y "%OUTPUT%\_vbhost_publish\AppCentralLib.dll" "%OUTPUT%\" >NUL
rmdir /S /Q "%OUTPUT%\_vbhost_publish"

echo.
echo === Building F# host ===
dotnet publish "C:\Beispiele\AppCentral\Examples\FSharpHost\FSharpHost.fsproj" ^
    -c Release -r win-x64 --self-contained false ^
    -o "%OUTPUT%\_fshost_publish"
if errorlevel 1 exit /b 1

copy /Y "%OUTPUT%\_fshost_publish\FSharpHost.exe" "%OUTPUT%\" >NUL
copy /Y "%OUTPUT%\_fshost_publish\FSharpHost.dll" "%OUTPUT%\" >NUL
copy /Y "%OUTPUT%\_fshost_publish\FSharpHost.runtimeconfig.json" "%OUTPUT%\" >NUL
copy /Y "%OUTPUT%\_fshost_publish\FSharp.Core.dll" "%OUTPUT%\" >NUL 2>NUL
REM AppCentralLib.dll already came from VB step (identical content); skip overwrite.
rmdir /S /Q "%OUTPUT%\_fshost_publish"

echo.
echo === Done ===
dir /b "%OUTPUT%\VBNetHost.exe" "%OUTPUT%\FSharpHost.exe" "%OUTPUT%\AppCentralLib.dll"
