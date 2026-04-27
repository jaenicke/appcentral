# F#

F# nutzt dieselbe `AppCentral.cs`-Bibliothek wie C#. Da `.fsproj` aber
keine `.cs`-Dateien in den F#-Compile mischen kann, bekommt jedes F#-Sample
einen kleinen **Per-Host C#-Companion**, der `AppCentral.cs` und die
Sample-`Interfaces.cs` per File-Link einbindet. Der F#-Host referenziert
ihn via `<ProjectReference>`.

Es gibt keine zentrale `AppCentralLibrary.dll` mehr - jeder Host bringt
seinen eigenen Companion mit. Hintergrund: Der Source-Generator hinter
`[GeneratedComInterface]` legt seine Marshalling-Stubs in genau die
Assembly, die das Interface deklariert. Diese müssen neben
`AppCentral.cs`'s `StrategyBasedComWrappers` liegen.

## Voraussetzungen

- .NET 10 SDK (oder .NET 8+) - F#-Compiler ist enthalten.

## Einbindung in ein eigenes Projekt

1. **Per-Host-Companion** `MyHost/AppCentralLib/AppCentralLib.csproj`:

   ```xml
   <Project Sdk="Microsoft.NET.Sdk">
     <PropertyGroup>
       <TargetFramework>net10.0</TargetFramework>
       <RootNamespace>AppCentralLib</RootNamespace>
       <AllowUnsafeBlocks>true</AllowUnsafeBlocks>
       <AssemblyName>AppCentralLib</AssemblyName>
     </PropertyGroup>
     <ItemGroup>
       <Compile Include="..\..\..\AppCentral.cs" Link="AppCentral.cs" />
       <Compile Include="..\Interfaces.cs"        Link="Interfaces.cs" />
     </ItemGroup>
   </Project>
   ```

2. **F#-Host** referenziert den Companion:

   ```xml
   <Project Sdk="Microsoft.NET.Sdk">
     <PropertyGroup>
       <OutputType>Exe</OutputType>
       <TargetFramework>net10.0</TargetFramework>
       <PlatformTarget>x64</PlatformTarget>
     </PropertyGroup>
     <ItemGroup>
       <Compile Include="Program.fs" />
     </ItemGroup>
     <ItemGroup>
       <ProjectReference Include="AppCentralLib\AppCentralLib.csproj" />
     </ItemGroup>
   </Project>
   ```

## Beispiel - Host

```fsharp
open System
open AppCentralLib

[<EntryPoint>]
let main args =
    TAppCentral.LoadPlugin(args.[0]) |> ignore

    // TryGet: out-Parameter werden in F# zu Tupeln
    match TAppCentral.TryGet<IExample>() with
    | true, ex when ex <> null ->
        let hello = ex.SayHello("Welt")
        let sum = ex.Add(3, 4)
        printfn "SayHello: %s" hello
        printfn "Add: %d" sum
    | _ ->
        printfn "Nicht gefunden"

    // GetAllPlugins
    let all = TAppCentral.GetAllPlugins<IExample>()
    all |> Seq.iteri (fun i ex -> printfn "Plugin %d: %s" i (ex.SayHello "Plugin"))

    // Get<T> wirft Exception
    try
        TAppCentral.Get<IExampleParams>() |> ignore
    with
    | :? AppCentralInterfaceNotFoundException as e -> printfn "%s" e.Message

    TAppCentral.Shutdown()
    0
```

## Wichtige Regeln

### `out`-Parameter werden zu Tupeln

`TAppCentral.TryGet<T>(out T result, ...)` in C# wird in F# zu einer Funktion,
die ein Tupel `(bool, T)` zurückgibt:

```fsharp
match TAppCentral.TryGet<IExample>() with
| true, ex when ex <> null -> ...
| _ -> ...
```

Alternativ funktioniert auch:

```fsharp
let mutable ex = Unchecked.defaultof<IExample>
let success = TAppCentral.TryGet<IExample>(&ex)
```

### F#-String-Interpolation und Quotes

In `printfn $"{x}"`-String-Interpolation darf man **keine** String-Literals mit
Anführungszeichen verwenden. Sonst kommt
`error FS3373: Ungültige interpolierte Zeichenfolge`.

```fsharp
// ✗ schlechtes Beispiel:
printfn $"{ex.SayHello(\"Welt\")}"

// ✓ besser - %s-Format:
let hello = ex.SayHello("Welt")
printfn "%s" hello

// oder:
printfn "%s" (ex.SayHello("Welt"))
```

### Plattform x64

`<PlatformTarget>x64</PlatformTarget>` setzen.

### Interface-Refs vor Shutdown freigeben

Wie bei C#: am besten in einer eigenen Funktion verwenden, damit `out`-
Variablen am Funktionsende automatisch freigegeben werden.

## API-Übersicht

Identisch zu C# (siehe [CSharp.md](CSharp.md)). Aufruf-Syntax:

```fsharp
TAppCentral.LoadPlugin("foo.dll")              // bool
TAppCentral.UnloadPlugin("foo.dll")            // bool
TAppCentral.PluginLoaded("foo.dll")            // bool
TAppCentral.PluginCount                        // int (property)
TAppCentral.PluginFilename(0)                  // string

TAppCentral.Register<IExample>(impl)
TAppCentral.Unregister<IExample>()

let ok, ex = TAppCentral.TryGet<IExample>()    // (bool, T)
let ex = TAppCentral.Get<IExample>()           // T or throw
let all = TAppCentral.GetAllPlugins<IExample>() // List<T>

TAppCentral.Shutdown()
```

## Build

```
Build\build_dotnet_hosts.bat
```

Baut VB.NET-Host und F#-Host gemeinsam. Erzeugt `Output/FSharpHost.exe`.
