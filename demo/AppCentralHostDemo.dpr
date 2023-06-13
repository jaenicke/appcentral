program AppCentralHostDemo;

uses
  Vcl.Forms,
  AppCentralHostDemoMain in 'AppCentralHostDemoMain.pas' {frmAppCentralHostDemoMain},
  AppCentral in '..\source\AppCentral.pas',
  AppCentralDemoDialogs in 'AppCentralDemoDialogs.pas',
  AppCentralDemoInterfaces in '..\source\AppCentralDemoInterfaces.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmAppCentralHostDemoMain, frmAppCentralHostDemoMain);
  Application.Run;
end.
