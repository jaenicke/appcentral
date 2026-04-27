# F#

🇩🇪 [Deutsche Version](FSharp.de.md)

F# reuses the same `AppCentral.cs` integration library that C# uses.
Since `.fsproj` projects can't mix `.cs` source files into the F# compile,
each F# sample ships a small **per-host C# companion project** that
file-links `AppCentral.cs` plus the sample `Interfaces.cs`. The F# host
references the companion via `<ProjectReference>`.

There is no central shared `AppCentralLibrary.dll` — every host wires its
own copy. This matters because the source generator behind
`[GeneratedComInterface]` puts its marshalling stubs into the assembly
that defines the interface, and those need to live alongside
`AppCentral.cs`'s `StrategyBasedComWrappers`.

## Requirements

- .NET 10 SDK (or .NET 8+) — F# compiler is included.

## Adding it to your own project

1. **Per-host companion project** `MyHost/AppCentralLib/AppCentralLib.csproj`:

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

2. The **F# host** references the companion:

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

## Example — host

```fsharp
open System
open AppCentralLib

[<EntryPoint>]
let main args =
    TAppCentral.LoadPlugin(args.[0]) |> ignore

    // TryGet: out parameters become tuples in F#
    match TAppCentral.TryGet<IExample>() with
    | true, ex when ex <> null ->
        let hello = ex.SayHello("World")
        let sum = ex.Add(3, 4)
        printfn "SayHello: %s" hello
        printfn "Add: %d" sum
    | _ ->
        printfn "Not found"

    // GetAllPlugins
    let all = TAppCentral.GetAllPlugins<IExample>()
    all |> Seq.iteri (fun i ex -> printfn "Plugin %d: %s" i (ex.SayHello "Plugin"))

    // Get<T> throws
    try
        TAppCentral.Get<IExampleParams>() |> ignore
    with
    | :? AppCentralInterfaceNotFoundException as e -> printfn "%s" e.Message

    TAppCentral.Shutdown()
    0
```

## Important rules

### `out` parameters become tuples

`TAppCentral.TryGet<T>(out T result, ...)` from C# becomes a function in F#
that returns a tuple `(bool, T)`:

```fsharp
match TAppCentral.TryGet<IExample>() with
| true, ex when ex <> null -> ...
| _ -> ...
```

Alternatively:

```fsharp
let mutable ex = Unchecked.defaultof<IExample>
let success = TAppCentral.TryGet<IExample>(&ex)
```

### F# string interpolation and quotes

Inside an interpolated string `printfn $"{x}"`, you can't use string literals
with quotation marks. You'll get
`error FS3373: invalid interpolated string`.

```fsharp
// ✗ bad:
printfn $"{ex.SayHello(\"World\")}"

// ✓ better — use %s:
let hello = ex.SayHello("World")
printfn "%s" hello

// or:
printfn "%s" (ex.SayHello("World"))
```

### Platform x64

Set `<PlatformTarget>x64</PlatformTarget>`.

### Release interface refs before Shutdown

Same as C#: best to use within its own function, so `out` variables get
released automatically at function exit.

## API summary

Identical to C# (see [CSharp.md](CSharp.md)). Call syntax:

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

Builds VB.NET and F# hosts together. Produces `Output/FSharpHost.exe`.
