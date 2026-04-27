Imports System
Imports AppCentralLib

Module Program
    Sub Main(args As String())
        Console.WriteLine("=== AppCentral VB.NET Host ===")
        Console.WriteLine()

        Dim dllPath As String = If(args.Length > 0, args(0), "ExampleDelphiDLL.dll")

        Console.WriteLine($"Loading {dllPath}...")
        If Not TAppCentral.LoadPlugin(dllPath) Then
            Console.WriteLine("ERROR: Could not load plugin")
            Return
        End If
        Console.WriteLine("Loaded.")

        If args.Length > 1 Then
            If TAppCentral.LoadPlugin(args(1)) Then
                Console.WriteLine($"Second plugin loaded: {args(1)}")
            End If
        End If

        Console.WriteLine()
        Console.WriteLine("--- Plugin list ---")
        For i As Integer = 0 To TAppCentral.PluginCount - 1
            Console.WriteLine($"  [{i}] {TAppCentral.PluginFilename(i)}")
        Next
        Console.WriteLine()

        ' TryGet
        Dim example As IExample = Nothing
        If TAppCentral.TryGet(Of IExample)(example) Then
            Console.WriteLine($"IExample.SayHello: {example.SayHello("World")}")
            Console.WriteLine($"IExample.Add(3, 4): {example.Add(3, 4)}")
        Else
            Console.WriteLine("ERROR: IExample not found!")
        End If

        Console.WriteLine()
        Dim allExamples = TAppCentral.GetAllPlugins(Of IExample)()
        Console.WriteLine($"Plugins offering IExample: {allExamples.Count}")
        For i As Integer = 0 To allExamples.Count - 1
            Console.WriteLine($"  Plugin {i}: {allExamples(i).SayHello("Plugin")}")
        Next

        Console.WriteLine()
        Console.WriteLine("Teste Get<unbekannt>...")
        Try
            Dim p = TAppCentral.[Get](Of IExampleParams)()
            Console.WriteLine("  -> unexpected: interface found")
        Catch ex As AppCentralInterfaceNotFoundException
            Console.WriteLine($"  -> wie erwartet: {ex.Message}")
        End Try

        Console.WriteLine()
        Console.WriteLine("Shutdown...")
        TAppCentral.Shutdown()
        Console.WriteLine("Done.")
    End Sub
End Module
