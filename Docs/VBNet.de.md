# VB.NET

VB.NET nutzt dieselbe `AppCentral.cs`-Bibliothek wie C#. Da `.vbproj`
allerdings keine `.cs`-Dateien direkt kompilieren kann, bekommt jedes
VB.NET-Sample einen kleinen **Per-Host C#-Companion** mitgeliefert, der
`AppCentral.cs` und die Sample-`Interfaces.cs` per File-Link einbindet.
Der Host referenziert diesen Companion via `<ProjectReference>`.

Es gibt keine zentrale `AppCentralLibrary.dll` mehr - jeder Host bringt
seinen eigenen Companion mit. Hintergrund: Der Source-Generator hinter
`[GeneratedComInterface]` legt seine Marshalling-Stubs in genau die
Assembly, die das Interface deklariert. Diese Stubs müssen neben
`AppCentral.cs`'s `StrategyBasedComWrappers` liegen.

## Voraussetzungen

- .NET 10 SDK (oder .NET 8+) - VB.NET-Compiler ist enthalten.

## Einbindung in ein eigenes Projekt

1. **Per-Host-Companion** `MyVbHost/AppCentralLib/AppCentralLib.csproj`,
   der `AppCentral.cs` und *deine* eigenen Interfaces einbindet:

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

2. **VB.NET-Host** referenziert den lokalen Companion:

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

## Beispiel - Host

```vb
Imports System
Imports AppCentralLib

Module Program
    Sub Main(args As String())
        TAppCentral.LoadPlugin("MyPlugin.dll")

        Dim example As IExample = Nothing
        If TAppCentral.TryGet(Of IExample)(example) Then
            Console.WriteLine(example.SayHello("Welt"))
            Console.WriteLine(example.Add(3, 4))
        End If

        ' Liste aller Plugins die IExample anbieten
        Dim allExamples = TAppCentral.GetAllPlugins(Of IExample)()
        For i As Integer = 0 To allExamples.Count - 1
            Console.WriteLine($"Plugin {i}: {allExamples(i).SayHello("Plugin")}")
        Next

        ' Get<T> wirft Exception wenn nicht gefunden
        Try
            Dim p = TAppCentral.[Get](Of IExampleParams)()
        Catch ex As AppCentralInterfaceNotFoundException
            Console.WriteLine(ex.Message)
        End Try

        TAppCentral.Shutdown()
    End Sub
End Module
```

## Wichtige Regeln

### `Get` ist ein VB.NET-Schlüsselwort

Beim Aufruf von `TAppCentral.Get<T>` muss in VB.NET der Methodenname mit
eckigen Klammern eingerahmt werden, weil `Get` ein reserviertes Wort ist:

```vb
Dim p = TAppCentral.[Get](Of IExampleParams)()
```

`TryGet` und die anderen sind unproblematisch.

### Interface-Refs vor Shutdown freigeben

Wie bei C#: lokale Interface-Variablen halten den COM-RCW. Vor `Shutdown` sollte
die DLL keine offenen Refs mehr haben. Im Zweifel die Verwendung in einer
eigenen Sub kapseln, sodass der Compiler die Variable am Sub-Ende freigibt:

```vb
Sub RunExample()
    Dim example As IExample = Nothing
    If TAppCentral.TryGet(Of IExample)(example) Then
        Console.WriteLine(example.SayHello("Welt"))
    End If
End Sub
' example ist hier weg

Sub Main(args As String())
    TAppCentral.LoadPlugin("foo.dll")
    RunExample()
    TAppCentral.Shutdown()
End Sub
```

### Plattform x64

`<PlatformTarget>x64</PlatformTarget>` setzen, damit das EXE explizit x64 ist
(passend zu den x64-DLLs).

## API-Übersicht

Identisch zu C# (siehe [CSharp.md](CSharp.md)).

## Build

```
Build\build_dotnet_hosts.bat
```

Baut VB.NET-Host und F#-Host gemeinsam (beide brauchen die gleiche
eigenen `AppCentralLib`-Companion). Erzeugt `Output/VBNetHost.exe`.
