@echo off
setlocal
set "BUILD=%~dp0"
set "ROOT=%BUILD%.."
set "OUTPUT=%ROOT%\Output"
set "EXAMPLES=%ROOT%\Examples"
if not exist "%OUTPUT%" mkdir "%OUTPUT%"

if "%JAVA_HOME%"=="" set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot"

if not exist "%JAVA_HOME%\bin\javac.exe" (
    echo ERROR: JDK not found in JAVA_HOME=%JAVA_HOME%
    exit /b 1
)
set "PATH=%JAVA_HOME%\bin;%PATH%"

REM JNA jars must be in %EXAMPLES%\JavaHost\lib\
REM Download from: https://github.com/java-native-access/jna/releases
REM   - jna-5.14.0.jar
REM   - jna-platform-5.14.0.jar
set LIB=%EXAMPLES%\JavaHost\lib
set CP=%LIB%\jna-5.14.0.jar;%LIB%\jna-platform-5.14.0.jar

if not exist "%LIB%\jna-5.14.0.jar" (
    echo ERROR: JNA not found in %LIB%
    echo.
    echo Please download JNA and place it in %LIB%:
    echo   jna-5.14.0.jar
    echo   jna-platform-5.14.0.jar
    echo Download: https://github.com/java-native-access/jna/releases
    exit /b 1
)

echo === Building Java host ===
javac -cp "%CP%" -d "%OUTPUT%" ^
    "%ROOT%\AppCentral.java" ^
    "%EXAMPLES%\JavaHost\IExampleProxy.java" ^
    "%EXAMPLES%\JavaHost\Main.java"
if errorlevel 1 exit /b 1

REM Copy JNA jars to Output so Main is easily runnable
copy /Y "%LIB%\jna-5.14.0.jar" "%OUTPUT%\" >NUL
copy /Y "%LIB%\jna-platform-5.14.0.jar" "%OUTPUT%\" >NUL

REM Generate run script in the Build folder. The generated script derives
REM its own paths from %~dp0 so it stays portable.
set RUN_CMD=%BUILD%run_java_host.cmd
> "%RUN_CMD%" echo @echo off
>> "%RUN_CMD%" echo set "JAVA_HOME=%JAVA_HOME%"
>> "%RUN_CMD%" echo set "PATH=%%JAVA_HOME%%\bin;%%JAVA_HOME%%\bin\server;%%PATH%%"
>> "%RUN_CMD%" echo set "OUT=%%~dp0..\Output"
>> "%RUN_CMD%" echo java --enable-native-access=ALL-UNNAMED -cp "%%OUT%%;%%OUT%%\jna-5.14.0.jar;%%OUT%%\jna-platform-5.14.0.jar" Main %%*

echo.
echo === Done ===
echo Output: %OUTPUT%\Main.class (+ JNA jars)
echo Run with: %RUN_CMD% [DLL path]
