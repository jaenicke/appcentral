{
  ***** BEGIN LICENSE BLOCK *****
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1 (the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL/

  Software distributed under the License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
  for the specific language governing rights and limitations under the
  License.

  The Original Code is AppCentral.

  The Initial Developer of the Original Code is Sebastian Jänicke.
  Portions created by the Initial Developer are Copyright (C) 2023
  the Initial Developer. All Rights Reserved.

  Contributor(s):
    none

  Alternatively, the contents of this file may be used under the terms of
  either the GNU General Public License Version 2 or later (the "GPL"), or
  the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
  in which case the provisions of the GPL or the LGPL are applicable instead
  of those above. If you wish to allow use of your version of this file only
  under the terms of either the GPL or the LGPL, and not to allow others to
  use your version of this file under the terms of the MPL, indicate your
  decision by deleting the provisions above and replace them with the notice
  and other provisions required by the GPL or the LGPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the MPL, the GPL or the LGPL.

  ***** END LICENSE BLOCK *****
}

unit AppCentralHostDemoMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  AppCentral, AppCentralDemoInterfaces;

type
  THostDemo = class(TInterfacedObject, IHostDemoInterface)
  protected
    function GetMagicNumber: LongInt; safecall;
  end;

  TfrmAppCentralHostDemoMain = class(TForm)
    btnLoadPluginDelphi: TButton;
    Label1: TLabel;
    Label2: TLabel;
    btnLoadPluginCS: TButton;
    btnFirstDemo: TButton;
    Label3: TLabel;
    StaticText1: TStaticText;
    StaticText2: TStaticText;
    Label5: TLabel;
    btnLoadPlugins: TButton;
    btnSecondDemo: TButton;
    Label6: TLabel;
    memResults: TMemo;
    btnInitHostInterface: TButton;
    Label4: TLabel;
    procedure btnLoadPluginDelphiClick(Sender: TObject);
    procedure btnInitHostInterfaceClick(Sender: TObject);
    procedure btnLoadPluginCSClick(Sender: TObject);
    procedure btnFirstDemoClick(Sender: TObject);
    procedure btnLoadPluginsClick(Sender: TObject);
    procedure btnSecondDemoClick(Sender: TObject);
  private
    procedure LoadPlugin(const AFilename: string);
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
  end;

var
  frmAppCentralHostDemoMain: TfrmAppCentralHostDemoMain;

implementation

{$R *.dfm}

{ THostDemo }

function THostDemo.GetMagicNumber: LongInt;
begin
  Result := 42;
end;

{ TfrmAppCentralHostDemoMain }

procedure TfrmAppCentralHostDemoMain.LoadPlugin(const AFilename: string);
begin
  if TAppCentral.LoadPlugin(AFilename) then
  begin
    btnLoadPluginCS.Enabled := False;
    btnLoadPluginDelphi.Enabled := False;
    btnLoadPlugins.Enabled := False;
  end
  else
    TAppCentral.Get<IAppDialogs>.ShowMessage('Plugin could not be loaded!');
end;

procedure TfrmAppCentralHostDemoMain.btnLoadPluginCSClick(Sender: TObject);
begin
  LoadPlugin('AppCentralClientDemoCS.dll');
  btnLoadPlugins.Enabled := False;
end;

procedure TfrmAppCentralHostDemoMain.btnLoadPluginDelphiClick(Sender: TObject);
begin
  LoadPlugin('AppCentralClientDLLDemo.dll');
  btnLoadPlugins.Enabled := False;
end;

procedure TfrmAppCentralHostDemoMain.btnLoadPluginsClick(Sender: TObject);
begin
  LoadPlugin('AppCentralClientDLLDemo.dll');
  LoadPlugin('AppCentralClientDemoCS.dll');
  btnFirstDemo.Enabled := False;
end;

procedure TfrmAppCentralHostDemoMain.btnSecondDemoClick(Sender: TObject);
var
  Plugins: TArray<IClientDemoInterface>;
  CurrentPlugin: IClientDemoInterface;
  DemoInfo: IDemoInfoInterface;
begin
  memResults.Lines.Clear;
  Plugins := TAppCentral.GetAllPlugins<IClientDemoInterface>;
  for CurrentPlugin in Plugins do
  begin
    DemoInfo := CurrentPlugin.GetInfo('Test');
    memResults.Lines.Add('*********************************************');
    memResults.Lines.Add(DemoInfo.GetDisplayText('window caption'));
  end;
end;

procedure TfrmAppCentralHostDemoMain.btnFirstDemoClick(Sender: TObject);
var
  Dialogs: IAppDialogs;
  DemoInterface: IClientDemoInterface;
  DemoInfo: IDemoInfoInterface;
begin
  Dialogs := TAppCentral.Get<IAppDialogs>;
  if TAppCentral.TryGet<IClientDemoInterface>(DemoInterface) then
  begin
    DemoInfo := DemoInterface.GetInfo('Test');
    Dialogs.ShowMessage(DemoInfo.GetDisplayText('window caption'));
  end
  else
    Dialogs.ShowMessage('Could not find IClientDemoInterface from plugin DLL!');
end;

procedure TfrmAppCentralHostDemoMain.btnInitHostInterfaceClick(Sender: TObject);
begin
  btnInitHostInterface.Enabled := False;
  TAppCentral.Reg<IHostDemoInterface>(THostDemo.Create);
end;

end.
