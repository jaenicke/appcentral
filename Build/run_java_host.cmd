@echo off
set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot"
set "PATH=%JAVA_HOME%\bin;%JAVA_HOME%\bin\server;%PATH%"
set "OUT=%~dp0..\Output"
java --enable-native-access=ALL-UNNAMED -cp "%OUT%;%OUT%\jna-5.14.0.jar;%OUT%\jna-platform-5.14.0.jar" Main %*
