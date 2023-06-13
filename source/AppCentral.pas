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

unit AppCentral;

interface

// safecall is important when using C#, otherwise the interfaces would not be compatible

uses
  System.Generics.Collections, Winapi.Windows, System.SysUtils, System.TypInfo;

type
  IAppCentral = interface
  ['{08C68342-3187-4D4A-AE93-96277FBA3CA3}']
    function TryGet(AFromHost: LongBool; AGUID: TGUID; out AInterface: IInterface): LongBool; safecall;
    procedure ShutdownPlugin; safecall;
  end;

  TAppCentral = class(TInterfacedObject, IAppCentral)
  strict private
    type
      TPluginInfo = class
      strict private
        FFilename: string;
        FHandle: THandle;
        FClient: IAppCentral;
        function GetLoaded: Boolean;
      public
        constructor Create(const AFilename: string);
        function Load: Boolean;
        procedure Unload;
        property Filename: string read FFilename;
        property Handle: THandle read FHandle;
        property Client: IAppCentral read FCLient;
        property Loaded: Boolean read GetLoaded;
      end;
    class var
      FInstance: IAppCentral;
      {$IFDEF DEBUG}
      FDebugModuleName: string; // when debugging with DLL and host, you can see where you are
      {$IFEND}
      FHost: IAppCentral;
      FPlugins: TObjectList<TPluginInfo>;
      FSingletons: TDictionary<TGUID, IInterface>;
    class function GetGUID<T: IInterface>: TGUID; static; inline;
    class procedure UnloadPlugins; static;
  private
    class function RegisterHost(AHost: IAppCentral): IAppCentral;
  protected
    function TryGet(AFromHost: LongBool; AGUID: TGUID; out AInterface: IInterface): LongBool; overload; safecall;
    procedure ShutdownPlugin; safecall;
  public
    class constructor Create;
    class destructor Destroy;
    class procedure Reg<T: IInterface>(ASingletonInstance: T); overload; static;
    class procedure Unreg<T: IInterface>; static;
    class function Get<T: IInterface>: T; static;
    class function TryGet<T: IInterface>(out AInterface: T): Boolean; overload; static;
    class function GetAllPlugins<T: IInterface>: TArray<T>; static;
    class function LoadPlugin(const AFilename: string): Boolean; static;
    class function FindPlugin(const AFilename: string): TPluginInfo; static;
    class property Plugins: TObjectList<TPluginInfo> read FPlugins;
  end;

  EAppCentralInterfaceNotFound = class(Exception)
  public
    class function CreateNew<T: IInterface>: EAppCentralInterfaceNotFound;
  end;

implementation

type
  TRegisterAppCentralPlugin = function(AHost: IAppCentral; out AClient: IAppCentral): LongBool; stdcall;

{ TAppCentral }

class constructor TAppCentral.Create;
begin
  {$IFDEF DEBUG}
  FDebugModuleName := GetModuleName(HInstance);
  {$IFEND}
  FInstance := TAppCentral.Create;
  FSingletons := TDictionary<TGUID, IInterface>.Create;
  FPlugins := TObjectList<TPluginInfo>.Create(True);
end;

class destructor TAppCentral.Destroy;
begin
  UnloadPlugins;
  FreeAndNil(FPlugins);
  FreeAndNil(FSingletons);
  FHost := nil;
  FInstance := nil;
end;

class function TAppCentral.FindPlugin(const AFilename: string): TPluginInfo;
var
  CurrentPlugin: TPluginInfo;
begin
  for CurrentPlugin in FPlugins do
    if AnsiSameText(ExtractFileName(AFilename), ExtractFileName(CurrentPlugin.Filename)) then
      Exit(CurrentPlugin);
  Result := nil;
end;

class function TAppCentral.Get<T>: T;
begin
  if not TryGet<T>(Result) then
    raise EAppCentralInterfaceNotFound.CreateNew<T>;
end;

class function TAppCentral.GetGUID<T>: TGUID;
var
  SingletonType: PTypeData;
begin
  SingletonType := GetTypeData(TypeInfo(T));
  Result := SingletonType.GUID;
end;

class function TAppCentral.LoadPlugin(const AFilename: string): Boolean;
var
  NewPlugin: TPluginInfo;
begin
  NewPlugin := FindPlugin(AFilename);
  Result := Assigned(NewPlugin);
  if Result then
    Result := Result and NewPlugin.Loaded
  else
  begin
    NewPlugin := TPluginInfo.Create(AFilename);
    Result := NewPlugin.Load;
    FPlugins.Add(NewPlugin);
  end;
end;

class procedure TAppCentral.Reg<T>(ASingletonInstance: T);
begin
  FSingletons.AddOrSetValue(GetGUID<T>, ASingletonInstance);
end;

class function TAppCentral.RegisterHost(AHost: IAppCentral): IAppCentral;
begin
  Result := FInstance;
  FHost := AHost;
end;

procedure TAppCentral.ShutdownPlugin;
begin
  FHost := nil;
end;

function TAppCentral.TryGet(AFromHost: LongBool; AGUID: TGUID; out AInterface: IInterface): LongBool;
var
  CurrentPlugin: TPluginInfo;
begin
  Result := FSingletons.TryGetValue(AGUID, AInterface);
  if Assigned(FHost) and not AFromHost then
    Result := FHost.TryGet(False, AGUID, AInterface);
  if not Result then
    for CurrentPlugin in FPlugins do
    begin
      Result := CurrentPlugin.Client.TryGet(True, AGUID, AInterface);
      if Result then
        Exit;
    end;
end;

class function TAppCentral.TryGet<T>(out AInterface: T): Boolean;
var
  Guid: TGUID;
  Output: IInterface;
begin
  Guid := GetGUID<T>;
  Result := FInstance.TryGet(False, Guid, Output) and Supports(Output, Guid, AInterface);
end;

class function TAppCentral.GetAllPlugins<T>: TArray<T>;
var
  i: Integer;
  Guid: TGUID;
  CurrentPlugin: TPluginInfo;
  PluginInterface: IInterface;
  NewItem: T;
begin
  SetLength(Result, FPlugins.Count);
  i := 0;
  Guid := GetGUID<T>;
  for CurrentPlugin in FPlugins do
    if CurrentPlugin.Client.TryGet(True, Guid, PluginInterface) and Supports(PluginInterface, Guid, Result[i]) then
      Inc(i);
  SetLength(Result, i);
end;

class procedure TAppCentral.UnloadPlugins;
var
  CurrentPlugin: TPluginInfo;
begin
  for CurrentPlugin in FPlugins do
    CurrentPlugin.Unload;
end;

class procedure TAppCentral.Unreg<T>;
begin
  FSingletons.Remove(GetGUID<T>);
end;

{ TAppCentral.TPluginInfo }

constructor TAppCentral.TPluginInfo.Create(const AFilename: string);
begin
  FFilename := AFilename;
end;

function TAppCentral.TPluginInfo.GetLoaded: Boolean;
begin
  Result := FHandle <> 0;
end;

function TAppCentral.TPluginInfo.Load: Boolean;
var
  RegisterPlugin: TRegisterAppCentralPlugin;
begin
  FHandle := LoadLibrary(PChar(FFilename));
  Result := FHandle <> 0;
  if Result then
  begin
    @RegisterPlugin := GetProcAddress(FHandle, 'RegisterAppCentralPlugin');
    Result := Assigned(RegisterPlugin);
    if Result then
      Result := Result and RegisterPlugin(FInstance, FClient);
  end;
end;

procedure TAppCentral.TPluginInfo.Unload;
begin
  if Assigned(FClient) then
  begin
    FClient.ShutdownPlugin;
    FClient := nil; // important before FreeLibrary, otherwise interface reference from DLL remains open --> crash
  end;
  if Loaded then
    FreeLibrary(FHandle);
end;

{ EAppCentralInterfaceNotFound }

class function EAppCentralInterfaceNotFound.CreateNew<T>: EAppCentralInterfaceNotFound;
begin
  Result := EAppCentralInterfaceNotFound.CreateFmt('Could not find Interface %s!', [GetTypeName(TypeInfo(T))]);
end;

function RegisterAppCentralPlugin(AHost: IAppCentral; out AClient: IAppCentral): LongBool; stdcall; export;
begin
  AClient := TAppCentral.RegisterHost(AHost);
  Result := True;
end;

exports
  RegisterAppCentralPlugin;

end.
