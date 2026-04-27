program DelphiHost;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AppCentral in '..\..\AppCentral.pas',
  Interfaces in '..\Interfaces.pas';

procedure RunExample;
var
  Example: IExample;
begin
  if TAppCentral.TryGet<IExample>(Example) then
  begin
    WriteLn('IExample.SayHello: ', Example.SayHello('World'));
    WriteLn('IExample.Add(3, 4): ', Example.Add(3, 4));
  end
  else
    WriteLn('ERROR: IExample not found!');
end;

procedure RunAllPluginsDemo;
var
  AllExamples: TArray<IExample>;
  Example: IExample;
  I: Integer;
begin
  AllExamples := TAppCentral.GetAllPlugins<IExample>;
  WriteLn('Plugins offering IExample: ', Length(AllExamples));
  for I := 0 to High(AllExamples) do
  begin
    Example := AllExamples[I];
    WriteLn('  Plugin ', I, ': ', Example.SayHello('Plugin'));
  end;
end;

procedure DemoMultiplePlugins;
var
  I: Integer;
  Name: string;
begin
  WriteLn;
  WriteLn('--- Plugin list ---');
  for I := 0 to TAppCentral.PluginCount - 1 do
  begin
    Name := TAppCentral.PluginFilename(I);
    WriteLn('  [', I, '] ', Name);
  end;
end;

var
  DllPath: string;
  Params: IExampleParams;
begin
  try
    WriteLn('=== AppCentral Delphi host (modernized) ===');
    WriteLn;

    if ParamCount > 0 then
      DllPath := ParamStr(1)
    else
      DllPath := 'ExampleDelphiDLL.dll';

    WriteLn('Loading ', DllPath, '...');
    if not TAppCentral.LoadPlugin(DllPath) then
    begin
      WriteLn('ERROR: Could not load plugin');
      Exit;
    end;
    WriteLn('Loaded.');

    if (ParamCount > 1) and TAppCentral.LoadPlugin(ParamStr(2)) then
      WriteLn('Second plugin loaded: ', ParamStr(2));

    DemoMultiplePlugins;
    WriteLn;

    RunExample;
    WriteLn;
    RunAllPluginsDemo;

    WriteLn;
    WriteLn('Teste Get<unbekannt>...');
    try
      Params := TAppCentral.Get<IExampleParams>;
      WriteLn('  -> unexpected: interface found');
    except
      on E: EAppCentralInterfaceNotFound do
        WriteLn('  -> wie erwartet: ', E.Message);
    end;

    WriteLn;
    WriteLn('Shutdown...');
    TAppCentral.Shutdown;
    WriteLn('Done.');
  except
    on E: Exception do
      WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
  end;
end.
