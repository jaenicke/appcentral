library ExampleFPCDLL;

{$mode delphi}
{$H+}

uses
  AppCentral in '..\..\AppCentral.pas',
  Interfaces in '..\Interfaces.pas',
  ExampleFPCDLL.Impl in 'ExampleFPCDLL.Impl.pas';

exports
  RegisterHost;

begin
  TAppCentral.Register<IExample>(TExample.Create);
end.
