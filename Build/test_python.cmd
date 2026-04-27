@echo off
set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot"
set "PATH=%JAVA_HOME%\bin\server;%JAVA_HOME%\bin;%PATH%"
cd /d C:\Beispiele\AppCentral\Examples\PythonHost
python -u main.py %*
