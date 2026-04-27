# VB.NET

🇩🇪 [Deutsche Version](VBNet.de.md)

VB.NET reuses the same `AppCentral.cs` integration library that C# uses.
Since `.vbproj` projects can't compile `.cs` source files directly, each
VB.NET sample ships a tiny **per-host C# companion project** alongside the
host. The companion file-links `AppCentral.cs` plus the sample
`Interfaces.cs`, and the host references that companion via
`<ProjectReference>`.

There is no central shared `AppCentralLibrary.dll` — every host wires its
own copy. This matters because the source generator behind
`[GeneratedComInterface]` puts its marshalling stubs into whichever
assembly defines the interface, and those stubs need to live next to
`AppCentral.cs`'s `StrategyBasedComWrappers`.

## Requirements

- .NET 10 SDK (or .NET 8+) — VB.NET compiler is included.

## Adding it to your own project

1. **Per-host companion project** that file-links `AppCentral.cs` plus
   *your* interface definitions. Example
   `MyVbHost/AppCentralLib/AppCentralLib.csproj`:

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

2. The **VB.NET host** references the local companion:

   ```xml
   <Project Sdk="Microsoft.NET.Sdk">
     <PropertyGroup>
       <OutputType>Exe</OutputType>
       <TargetFramework>net10.0</TargetFramework>
       <PlatformTarget>x64</PlatformTarget>
     </PropertyGroup>
     <ItemGroup>
       <ProjectReference Include="AppCentralLib\AppCentralLib.csproj" />
     </ItemGroup>
   </Project>
   ```

## Example — host

```vb
Imports System
Imports AppCentralLib

Module Program
    Sub Main(args As String())
        TAppCentral.LoadPlugin("MyPlugin.dll")

        Dim example As IExample = Nothing
        If TAppCentral.TryGet(Of IExample)(example) Then
            Console.WriteLine(example.SayHello("World"))
            Console.WriteLine(example.Add(3, 4))
        End If

        ' List of every plugin offering IExample
        Dim allExamples = TAppCentral.GetAllPlugins(Of IExample)()
        For i As Integer = 0 To allExamples.Count - 1
            Console.WriteLine($"Plugin {i}: {allExamples(i).SayHello("Plugin")}")
        Next

        ' Get<T> throws if not found
        Try
            Dim p = TAppCentral.[Get](Of IExampleParams)()
        Catch ex As AppCentralInterfaceNotFoundException
            Console.WriteLine(ex.Message)
        End Try

        TAppCentral.Shutdown()
    End Sub
End Module
```

## Important rules

### `Get` is a VB.NET keyword

When calling `TAppCentral.Get<T>` in VB.NET, the method name needs square
brackets, because `Get` is a reserved word:

```vb
Dim p = TAppCentral.[Get](Of IExampleParams)()
```

`TryGet` and the others are not affected.

### Release interface refs before Shutdown

Same as C#: local interface variables hold the COM RCW. Before `Shutdown` the
DLL should not have any open refs left. When in doubt, wrap usage in its own
`Sub` so the compiler releases the variable at sub exit:

```vb
Sub RunExample()
    Dim example As IExample = Nothing
    If TAppCentral.TryGet(Of IExample)(example) Then
        Console.WriteLine(example.SayHello("World"))
    End If
End Sub
' example is gone here

Sub Main(args As String())
    TAppCentral.LoadPlugin("foo.dll")
    RunExample()
    TAppCentral.Shutdown()
End Sub
```

### Platform x64

Set `<PlatformTarget>x64</PlatformTarget>` so the EXE is explicitly x64
(matching the x64 DLLs).

## API summary

Identical to C# (see [CSharp.md](CSharp.md)).

## Build

```
Build\build_dotnet_hosts.bat
```

Builds VB.NET and F# hosts together. Each pulls its own
`AppCentralLib/AppCentralLib.csproj` companion via ProjectReference.
Produces `Output/VBNetHost.exe`.
