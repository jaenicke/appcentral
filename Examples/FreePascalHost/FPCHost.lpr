program FPCHost;

{$mode delphi}
{$H+}
{$APPTYPE CONSOLE}

uses
  SysUtils,
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
  All: TArray<IExample>;
  I: Integer;
begin
  All := TAppCentral.GetAllPlugins<IExample>;
  WriteLn('Plugins offering IExample: ', Length(All));
  for I := 0 to High(All) do
    WriteLn('  Plugin ', I, ': ', All[I].SayHello('Plugin'));
end;

var
  DllPath: string;
  Params: IExampleParams;
  I: Integer;
begin
  try
    WriteLn('=== AppCentral FreePascal Host ===');
    WriteLn;

    if ParamCount > 0 then
      DllPath := ParamStr(1)
    else
      DllPath := 'ExampleFPCDLL.dll';

    WriteLn('Loading ', DllPath, '...');
    if not TAppCentral.LoadPlugin(DllPath) then
    begin
      WriteLn('ERROR: Could not load plugin');
      Exit;
    end;
    WriteLn('Loaded.');

    if (ParamCount > 1) and TAppCentral.LoadPlugin(ParamStr(2)) then
      WriteLn('Second plugin loaded: ', ParamStr(2));

    WriteLn;
    WriteLn('--- Plugin list ---');
    for I := 0 to TAppCentral.PluginCount - 1 do
      WriteLn('  [', I, '] ', TAppCentral.PluginFilename(I));
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
