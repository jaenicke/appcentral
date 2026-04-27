(*
 * Copyright (c) 2026 Sebastian Jänicke (github.com/jaenicke)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *)
unit AppCentral;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

{
  AppCentral - cross-language interface exchange between host and DLLs.

   - "FromHost" flag in IAppCentralProvider prevents infinite loops when the
     host forwards requests between plugins (plugin-to-plugin via the host).
   - Get<T> raises EAppCentralInterfaceNotFound if the interface is missing.
   - TryGet<T> out-param pattern without exception.
   - GetAllPlugins<T>: all plugins that offer a given interface.
   - Plugin enumeration (PluginCount/PluginFilenames) and LoadPlugin with
     filename deduplication.
}

interface

uses
  {$IFDEF FPC}
  SysUtils, Generics.Collections, TypInfo, Windows, ActiveX;
  {$ELSE}
  System.SysUtils, System.Generics.Collections, System.TypInfo,
  Winapi.Windows, Winapi.ActiveX;
  {$ENDIF}

type
  /// <summary>
  /// Provider interface between host and DLLs. The FromHost flag prevents a
  /// request that was forwarded by the host from looping back to the host
  /// (infinite loop). GUID changed (D9C1 instead of D9C0) compared to the
  /// previous version: the vtable is incompatible due to the new FromHost
  /// parameter.
  /// </summary>
  IAppCentralProvider = interface(IUnknown)
    ['{F7E8D9C1-B1A2-4E3F-8071-926354AABBCC}']
    function GetInterface(FromHost: LongBool; const IID: TGUID;
      const Params: IInterface; out Obj: IUnknown): HResult; stdcall;
    function Shutdown: HResult; stdcall;
  end;

  /// <summary>Raised when Get&lt;T&gt; cannot find the requested interface.</summary>
  EAppCentralInterfaceNotFound = class(Exception)
  public
    constructor CreateForType(const TypeName: string);
  end;

  {$IFDEF FPC}
  // FPC 3.2.2 has no "reference to function" - factories only as methods
  TInterfaceFactory = function(const Params: IInterface): IInterface of object;
  {$ELSE}
  TInterfaceFactory = reference to function(const Params: IInterface): IInterface;
  /// <summary>Type-safe parameterless factory: `function: T`.</summary>
  TAppCentralProviderCallback<T> = reference to function: T;
  /// <summary>Type-safe factory with typed initialisation parameter.</summary>
  TAppCentralProviderCallback<TParam, T> = reference to function(const AParams: TParam): T;
  {$ENDIF}

  TRegistryEntry = record
    Instance: IInterface;
    Factory: TInterfaceFactory;
  end;

  TPluginInfo = record
    Handle: HMODULE;
    Provider: IAppCentralProvider;
    Filename: string;
  end;

  /// <summary>
  /// Central static class for interface exchange.
  /// Used in both hosts and DLLs (the same code; depending on the module,
  /// different fields are populated: hosts have plugins, DLLs have a host
  /// provider).
  /// </summary>
  TAppCentral = class
  private
    class var FRegistry: TDictionary<TGUID, TRegistryEntry>;
    class var FPlugins: TList<TPluginInfo>;
    class var FHostProvider: IAppCentralProvider;
    class var FLocalProvider: IAppCentralProvider;
    class procedure EnsureInitialized;
    class function GetGUID<T: IInterface>: TGUID; static; inline;
    class function FindPluginIndex(const Filename: string): Integer; static;
  public
    // ===================== Registration =====================
    /// <summary>Register an interface with a singleton instance.
    /// The parameter is deliberately *not* `const`. With `const`, Delphi's
    /// implicit class-to-interface conversion at the call site would not fire
    /// (no managed temporary), forcing callers into an intermediate IInterface
    /// variable or an explicit `as IFoo` cast.
    /// Also a non-overloaded name to keep generic overload resolution simple -
    /// the factory variants live under `RegisterProvider` for the same reason.</summary>
    class procedure Register<T: IInterface>(Instance: T);
    {$IFNDEF FPC}
    /// <summary>Register an interface with a parameterless typed factory.
    /// Distinct method name (not another `Register` overload) so Delphi's
    /// generic overload resolution stays unambiguous when a caller passes an
    /// instance whose type still needs an implicit class-to-interface cast.</summary>
    class procedure RegisterProvider<T: IInterface>(
      const Provider: TAppCentralProviderCallback<T>); overload;
    /// <summary>Register an interface with a typed factory taking a typed parameter.</summary>
    class procedure RegisterProvider<TParam: IInterface; T: IInterface>(
      const Provider: TAppCentralProviderCallback<TParam, T>); overload;
    {$ENDIF}
    /// <summary>Remove an interface from the local registry (important in finalization).</summary>
    class procedure Unregister<T: IInterface>;

    // ===================== Backwards compatibility =====================
    /// <summary>Legacy alias for `Register&lt;T&gt;(Instance)` from the predecessor
    /// project. Use `Register&lt;T&gt;` in new code.</summary>
    class procedure Reg<T: IInterface>(ASingletonInstance: T); overload; static;
      deprecated 'Use Register<T>(Instance) instead';
    /// <summary>Legacy alias for `Unregister&lt;T&gt;` from the predecessor project.
    /// Use `Unregister&lt;T&gt;` in new code.</summary>
    class procedure Unreg<T: IInterface>; static;
      deprecated 'Use Unregister<T> instead';

    // ===================== Lookup =====================
    /// <summary>Get an interface. Raises EAppCentralInterfaceNotFound if missing.</summary>
    class function Get<T: IInterface>: T; overload;
    {$IFNDEF FPC}
    /// <summary>Get an interface, passing typed initialisation parameters.</summary>
    class function Get<TParam: IInterface; T: IInterface>(const Params: TParam): T; overload;
    {$ENDIF}
    /// <summary>Try to get an interface without raising. Returns false if missing.</summary>
    class function TryGet<T: IInterface>(out AInterface: T): Boolean; overload;
    {$IFNDEF FPC}
    /// <summary>TryGet with typed initialisation parameters.</summary>
    class function TryGet<TParam: IInterface; T: IInterface>(
      const Params: TParam; out AInterface: T): Boolean; overload;
    {$ENDIF}

    /// <summary>All plugins that offer the given interface (host side).</summary>
    class function GetAllPlugins<T: IInterface>: TArray<T>;

    // ===================== Plugin management (host only) =====================
    /// <summary>Load a plugin. Plugins already loaded are not loaded again.
    /// Returns true on success, false if the plugin can't be loaded.</summary>
    class function LoadPlugin(const Filename: string): Boolean;
    /// <summary>Unload a specific plugin.</summary>
    class function UnloadPlugin(const Filename: string): Boolean;
    /// <summary>Check whether a plugin (by filename) is loaded.</summary>
    class function PluginLoaded(const Filename: string): Boolean;
    /// <summary>Number of loaded plugins.</summary>
    class function PluginCount: Integer;
    /// <summary>Filename of a loaded plugin.</summary>
    class function PluginFilename(Index: Integer): string;
    /// <summary>Notify all plugins, release providers, unload DLLs.</summary>
    class procedure Shutdown;

    // ===================== Internals =====================
    /// <summary>Routing logic: local -&gt; host -&gt; plugins (with FromHost handling).</summary>
    class function ResolveInterface(FromHost: Boolean; const IID: TGUID;
      const Params: IInterface; out Obj: IUnknown): HResult;
    /// <summary>Called by the DLL export RegisterHost.</summary>
    class function HandleRegisterHost(const HostProvider: IAppCentralProvider): IAppCentralProvider;
  end;

/// <summary>
/// DLL export. Automatically exported when this unit is used in a DLL.
/// Pointer-based for cross-language compatibility (Delphi returns interface
/// results through a hidden out parameter; C/C++/Rust expect the value in RAX).
/// </summary>
function RegisterHost(HostProvider: Pointer): Pointer; stdcall;

{$IFNDEF FPC}
// Delphi allows 'exports' inside a unit. FPC does not - in FPC the export
// has to be declared in the .lpr/.dpr file instead.
exports
  RegisterHost;
{$ENDIF}

implementation

type
  TLocalProvider = class(TInterfacedObject, IAppCentralProvider)
  public
    function GetInterface(FromHost: LongBool; const IID: TGUID;
      const Params: IInterface; out Obj: IUnknown): HResult; stdcall;
    function Shutdown: HResult; stdcall;
  end;

  TRegisterHostProc = function(HostProvider: Pointer): Pointer; stdcall;

{ EAppCentralInterfaceNotFound }

constructor EAppCentralInterfaceNotFound.CreateForType(const TypeName: string);
begin
  inherited CreateFmt('AppCentral: interface "%s" not registered', [TypeName]);
end;

{ TLocalProvider }

function TLocalProvider.GetInterface(FromHost: LongBool; const IID: TGUID;
  const Params: IInterface; out Obj: IUnknown): HResult; stdcall;
begin
  Result := TAppCentral.ResolveInterface(FromHost, IID, Params, Obj);
end;

function TLocalProvider.Shutdown: HResult; stdcall;
begin
  // Release host reference so the DLL can be unloaded cleanly
  TAppCentral.FHostProvider := nil;
  Result := S_OK;
end;

{ TAppCentral }

class procedure TAppCentral.EnsureInitialized;
begin
  if FRegistry = nil then
    FRegistry := TDictionary<TGUID, TRegistryEntry>.Create;
  if FPlugins = nil then
    FPlugins := TList<TPluginInfo>.Create;
  if FLocalProvider = nil then
    FLocalProvider := TLocalProvider.Create;
end;

class function TAppCentral.GetGUID<T>: TGUID;
begin
  Result := GetTypeData(TypeInfo(T))^.GUID;
end;

class function TAppCentral.FindPluginIndex(const Filename: string): Integer;
var
  I: Integer;
  Name: string;
begin
  Name := ExtractFileName(Filename);
  for I := 0 to FPlugins.Count - 1 do
    if SameText(ExtractFileName(FPlugins[I].Filename), Name) then
      Exit(I);
  Result := -1;
end;

// ============================================================================
// Routing logic
// ============================================================================

class function TAppCentral.ResolveInterface(FromHost: Boolean; const IID: TGUID;
  const Params: IInterface; out Obj: IUnknown): HResult;
var
  Entry: TRegistryEntry;
  Intf: IInterface;
  I: Integer;
begin
  EnsureInitialized;
  Obj := nil;

  // 1. Local registry
  if FRegistry.TryGetValue(IID, Entry) then
  begin
    if Assigned(Entry.Factory) then
      Intf := Entry.Factory(Params)
    else
      Intf := Entry.Instance;
    if Assigned(Intf) and (Intf.QueryInterface(IID, Obj) = S_OK) then
      Exit(S_OK);
  end;

  // 2. If not "from host" and we know the host -> ask the host.
  //    Pass FromHost=False so the host can keep routing.
  if not FromHost and Assigned(FHostProvider) then
  begin
    Result := FHostProvider.GetInterface(False, IID, Params, Obj);
    if Result = S_OK then Exit;
  end;

  // 3. Ask plugins (only the host has plugins). FromHost=True prevents the
  //    plugin from asking the host back -> infinite loop.
  for I := 0 to FPlugins.Count - 1 do
  begin
    if Assigned(FPlugins[I].Provider) then
    begin
      Result := FPlugins[I].Provider.GetInterface(True, IID, Params, Obj);
      if Result = S_OK then Exit;
    end;
  end;

  Result := E_NOINTERFACE;
end;

// ============================================================================
// Registration
// ============================================================================

class procedure TAppCentral.Register<T>(Instance: T);
var
  Entry: TRegistryEntry;
begin
  EnsureInitialized;
  Entry.Instance := Instance;
  Entry.Factory := nil;
  FRegistry.AddOrSetValue(GetGUID<T>, Entry);
end;

{$IFNDEF FPC}
class procedure TAppCentral.RegisterProvider<T>(
  const Provider: TAppCentralProviderCallback<T>);
var
  Entry: TRegistryEntry;
begin
  EnsureInitialized;
  Entry.Instance := nil;
  // The inner closure captures T from the outer generic scope, giving
  // us a typed factory bridged to the untyped internal factory signature.
  Entry.Factory :=
    function(const Params: IInterface): IInterface
    begin
      Result := Provider;
    end;
  FRegistry.AddOrSetValue(GetGUID<T>, Entry);
end;

class procedure TAppCentral.RegisterProvider<TParam, T>(
  const Provider: TAppCentralProviderCallback<TParam, T>);
var
  Entry: TRegistryEntry;
begin
  EnsureInitialized;
  Entry.Instance := nil;
  // Inner closure captures both TParam and T - the IInterface params get
  // typed back to TParam when calling the user-supplied factory.
  Entry.Factory :=
    function(const Params: IInterface): IInterface
    begin
      Result := Provider(TParam(Params));
    end;
  FRegistry.AddOrSetValue(GetGUID<T>, Entry);
end;
{$ENDIF}

class procedure TAppCentral.Unregister<T>;
begin
  if FRegistry <> nil then
    FRegistry.Remove(GetGUID<T>);
end;

// ============================================================================
// Backwards compatibility (deprecated)
// ============================================================================

class procedure TAppCentral.Reg<T>(ASingletonInstance: T);
begin
  Register<T>(ASingletonInstance);
end;

class procedure TAppCentral.Unreg<T>;
begin
  Unregister<T>;
end;

// ============================================================================
// Lookup
// ============================================================================

class function TAppCentral.TryGet<T>(out AInterface: T): Boolean;
var
  Obj: IUnknown;
  GUID: TGUID;
begin
  GUID := GetGUID<T>;
  Result := False;
  if ResolveInterface(False, GUID, nil, Obj) = S_OK then
    Result := Obj.QueryInterface(GUID, AInterface) = S_OK;
end;

{$IFNDEF FPC}
class function TAppCentral.TryGet<TParam, T>(const Params: TParam; out AInterface: T): Boolean;
var
  Obj: IUnknown;
  GUID: TGUID;
begin
  GUID := GetGUID<T>;
  Result := False;
  if ResolveInterface(False, GUID, Params, Obj) = S_OK then
    Result := Obj.QueryInterface(GUID, AInterface) = S_OK;
end;
{$ENDIF}

class function TAppCentral.Get<T>: T;
var
  TName: string;
  Obj: IUnknown;
  GUID: TGUID;
begin
  GUID := GetGUID<T>;
  if (ResolveInterface(False, GUID, nil, Obj) = S_OK) and
     Supports(Obj, GUID, Result) then
    Exit;
  {$IFDEF FPC}TName := string(PTypeInfo(TypeInfo(T))^.Name);
  {$ELSE}TName := string(GetTypeName(TypeInfo(T)));{$ENDIF}
  raise EAppCentralInterfaceNotFound.CreateForType(TName);
end;

{$IFNDEF FPC}
class function TAppCentral.Get<TParam, T>(const Params: TParam): T;
var
  TName: string;
  Obj: IUnknown;
  GUID: TGUID;
begin
  GUID := GetGUID<T>;
  if (ResolveInterface(False, GUID, Params, Obj) = S_OK) and
     Supports(Obj, GUID, Result) then
    Exit;
  TName := string(GetTypeName(TypeInfo(T)));
  raise EAppCentralInterfaceNotFound.CreateForType(TName);
end;
{$ENDIF}

class function TAppCentral.GetAllPlugins<T>: TArray<T>;
var
  GUID: TGUID;
  I, ResultCount: Integer;
  Obj: IUnknown;
  Item: T;
begin
  EnsureInitialized;
  Result := nil;  // initialise managed-type result before SetLength (FPC W5057)
  SetLength(Result, FPlugins.Count);
  ResultCount := 0;
  GUID := GetGUID<T>;
  for I := 0 to FPlugins.Count - 1 do
  begin
    if Assigned(FPlugins[I].Provider) and
       (FPlugins[I].Provider.GetInterface(True, GUID, nil, Obj) = S_OK) then
    begin
      if Obj.QueryInterface(GUID, Item) = S_OK then
      begin
        Result[ResultCount] := Item;
        Inc(ResultCount);
      end;
    end;
  end;
  SetLength(Result, ResultCount);
end;

// ============================================================================
// Plugin management
// ============================================================================

class function TAppCentral.LoadPlugin(const Filename: string): Boolean;
var
  Handle: HMODULE;
  Proc: TRegisterHostProc;
  RawResult: Pointer;
  Provider: IAppCentralProvider;
  Plugin: TPluginInfo;
begin
  EnsureInitialized;

  // Already loaded?
  if FindPluginIndex(Filename) >= 0 then
    Exit(True);

  Handle := {$IFDEF FPC}Windows{$ELSE}Winapi.Windows{$ENDIF}.LoadLibrary(PChar(Filename));
  if Handle = 0 then Exit(False);

  @Proc := GetProcAddress(Handle, 'RegisterHost');
  if not Assigned(Proc) then
  begin
    FreeLibrary(Handle);
    Exit(False);
  end;

  RawResult := Proc(Pointer(FLocalProvider));
  if RawResult = nil then
  begin
    FreeLibrary(Handle);
    Exit(False);
  end;

  Provider := IAppCentralProvider(RawResult);
  IAppCentralProvider(RawResult)._Release;

  Plugin.Handle := Handle;
  Plugin.Provider := Provider;
  Plugin.Filename := Filename;
  FPlugins.Add(Plugin);
  Result := True;
end;

class function TAppCentral.UnloadPlugin(const Filename: string): Boolean;
var
  Idx: Integer;
  Handle: HMODULE;
begin
  Result := False;
  if FPlugins = nil then Exit;
  Idx := FindPluginIndex(Filename);
  if Idx < 0 then Exit;

  // Notify provider
  try
    if Assigned(FPlugins[Idx].Provider) then
      FPlugins[Idx].Provider.Shutdown;
  except
  end;

  // Remember handle before removal
  Handle := FPlugins[Idx].Handle;
  FPlugins.Delete(Idx); // releases provider ref
  if Handle <> 0 then
    FreeLibrary(Handle);
  Result := True;
end;

class function TAppCentral.PluginLoaded(const Filename: string): Boolean;
begin
  Result := (FPlugins <> nil) and (FindPluginIndex(Filename) >= 0);
end;

class function TAppCentral.PluginCount: Integer;
begin
  if FPlugins = nil then
    Result := 0
  else
    Result := FPlugins.Count;
end;

class function TAppCentral.PluginFilename(Index: Integer): string;
begin
  Result := FPlugins[Index].Filename;
end;

class procedure TAppCentral.Shutdown;
var
  I: Integer;
  Handles: TArray<HMODULE>;
  Plugin: TPluginInfo;
begin
  if FPlugins = nil then Exit;

  // 1. Notify all plugins + clear provider refs explicitly to nil
  //    (FPC records with interface fields aren't always finalized correctly
  //    when the list is just cleared).
  SetLength(Handles, FPlugins.Count);
  for I := 0 to FPlugins.Count - 1 do
  begin
    Plugin := FPlugins[I];
    Handles[I] := Plugin.Handle;
    if Assigned(Plugin.Provider) then
    begin
      try
        Plugin.Provider.Shutdown;
      except
      end;
    end;
    Plugin.Provider := nil;
    Plugin.Handle := 0;
    FPlugins[I] := Plugin;
  end;

  // 2. Clear list
  FPlugins.Clear;

  // 3. Unload DLLs
  for I := High(Handles) downto 0 do
  begin
    if Handles[I] <> 0 then
      FreeLibrary(Handles[I]);
  end;
end;

class function TAppCentral.HandleRegisterHost(
  const HostProvider: IAppCentralProvider): IAppCentralProvider;
begin
  EnsureInitialized;
  FHostProvider := HostProvider;
  Result := FLocalProvider;
end;

// ============================================================================
// RegisterHost export (pointer-based for cross-language compatibility)
// ============================================================================

function RegisterHost(HostProvider: Pointer): Pointer; stdcall;
var
  LocalProv: IAppCentralProvider;
begin
  LocalProv := TAppCentral.HandleRegisterHost(IAppCentralProvider(HostProvider));
  Result := Pointer(LocalProv);
  if Result <> nil then
    IAppCentralProvider(Result)._AddRef;
end;

initialization
  CoInitializeEx(nil, COINIT_APARTMENTTHREADED);

finalization
  FreeAndNil(TAppCentral.FRegistry);
  FreeAndNil(TAppCentral.FPlugins);
  TAppCentral.FLocalProvider := nil;
  TAppCentral.FHostProvider := nil;
  CoUninitialize;

end.
