@echo off
setlocal
set "BUILD=%~dp0"
set "ROOT=%BUILD%.."
set "OUTPUT=%ROOT%\Output"
set "EXAMPLES=%ROOT%\Examples"
set SRCDIR=%EXAMPLES%\JavaDLL
if not exist "%OUTPUT%" mkdir "%OUTPUT%"

if "%JAVA_HOME%"=="" set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot"

if not exist "%JAVA_HOME%\include\jni.h" (
    echo FEHLER: JDK nicht gefunden in JAVA_HOME=%JAVA_HOME%
    exit /b 1
)

set "PATH=%JAVA_HOME%\bin;%PATH%"

REM Visual Studio Developer Environment (x64) fuer cl.exe
call "C:\Program Files\Microsoft Visual Studio\18\Professional\VC\Auxiliary\Build\vcvarsall.bat" x64 >NUL
if errorlevel 1 (
    echo FEHLER: vcvarsall.bat nicht gefunden
    exit /b 1
)

cd /d "%SRCDIR%"

echo === Kompiliere ExampleImpl.java ===
javac -d "%OUTPUT%" ExampleImpl.java
if errorlevel 1 exit /b 1

echo.
echo === Kompiliere ExampleJavaDLL.c (x64) ===
cl /nologo /LD /I"%JAVA_HOME%\include" /I"%JAVA_HOME%\include\win32" ^
   ExampleJavaDLL.c ole32.lib oleaut32.lib ^
   "%JAVA_HOME%\lib\jvm.lib" ^
   /Fe:"%OUTPUT%\ExampleJavaDLL.dll" /Fo:"%OUTPUT%\\"
if errorlevel 1 exit /b 1

del /q "%OUTPUT%\*.obj" "%OUTPUT%\*.exp" "%OUTPUT%\*.lib" 2>NUL

echo.
echo === Fertig ===
echo Output: %OUTPUT%\ExampleJavaDLL.dll, %OUTPUT%\ExampleImpl.class
echo.
echo Zum Ausfuehren muss jvm.dll im PATH sein:
echo   set PATH=%%JAVA_HOME%%\bin\server;%%PATH%%
