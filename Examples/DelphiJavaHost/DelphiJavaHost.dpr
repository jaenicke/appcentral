program DelphiJavaHost;

{
  Example: Delphi loads Java classes directly via JNI - no C bridge DLL.

  Zeigt zwei Anwendungsfaelle:
    1. Use a Java class directly as IExample (TJavaExampleAdapter)
    2. Den Java-Adapter in TAppCentral registrieren, damit normale DLLs
       the interface can be queried via AppCentral.Get<IExample>
       (Java erscheint von aussen wie eine normale Delphi/C++-Implementierung).

  Voraussetzung: JAVA_HOME ist gesetzt, ExampleImpl.class ist im angegebenen
  Classpath-Verzeichnis (Standard: C:\Beispiele\AppCentral\Output).
}

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AppCentral in '..\..\AppCentral.pas',
  Interfaces in '..\Interfaces.pas',
  AppCentral.JNI in '..\..\AppCentral.JNI.pas',
  JavaExampleAdapter in 'JavaExampleAdapter.pas';

procedure RunExample;
var
  Example: IExample;
begin
  // Get the interface from AppCentral - whether from Java, a DLL, or registered natively
  Example := TAppCentral.Get<IExample>;
  if Example <> nil then
  begin
    WriteLn('IExample.SayHello: ', Example.SayHello('World'));
    WriteLn('IExample.Add(3, 4): ', Example.Add(3, 4));
  end
  else
    WriteLn('ERROR: IExample not found!');
end;

var
  ClassPath: string;
begin
  try
    WriteLn('=== AppCentral Delphi+Java Host (direkt via JNI) ===');
    WriteLn;

    // Determine classpath (argument or default)
    if ParamCount > 0 then
      ClassPath := ParamStr(1)
    else
      ClassPath := 'C:\Beispiele\AppCentral\Output';

    WriteLn('Initialising JVM with classpath: ', ClassPath);
    TJVM.Initialize(ClassPath);
    WriteLn('JVM bereit.');
    WriteLn;

    // Register the Java class as IExample
    WriteLn('Registering Java class "ExampleImpl" as IExample...');
    TAppCentral.Register<IExample>(TJavaExampleAdapter.Create('ExampleImpl'));
    WriteLn('Registered.');
    WriteLn;

    // Call Java methods via AppCentral
    RunExample;

    WriteLn;
    WriteLn('Shutdown...');
    TAppCentral.Shutdown;
    TJVM.Finalize;
    WriteLn('Done.');
  except
    on E: Exception do
      WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
  end;

  WriteLn;
  WriteLn('Press Enter to exit...');
  ReadLn;
end.
