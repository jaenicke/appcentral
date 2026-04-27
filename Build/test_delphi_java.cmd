@echo off
set "BUILD=%~dp0"
set "ROOT=%BUILD%.."
set "OUTPUT=%ROOT%\Output"
set "EXAMPLES=%ROOT%\Examples"
set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot"
set "PATH=%JAVA_HOME%\bin\server;%JAVA_HOME%\bin;%PATH%"
%OUTPUT%\DelphiJavaHost.exe %* < nul
