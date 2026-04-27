open System
open AppCentralLib

[<EntryPoint>]
let main args =
    printfn "=== AppCentral F# Host ==="
    printfn ""

    let dllPath = if args.Length > 0 then args.[0] else "ExampleDelphiDLL.dll"

    printfn "Loading %s..." dllPath
    if not (TAppCentral.LoadPlugin(dllPath)) then
        printfn "ERROR: Could not load plugin"
        1
    else
        printfn "Loaded."

        if args.Length > 1 then
            if TAppCentral.LoadPlugin(args.[1]) then
                printfn "Second plugin loaded: %s" args.[1]

        printfn ""
        printfn "--- Plugin list ---"
        for i in 0 .. TAppCentral.PluginCount - 1 do
            printfn "  [%d] %s" i (TAppCentral.PluginFilename(i))
        printfn ""

        // TryGet (out param becomes a tuple in F#)
        match TAppCentral.TryGet<IExample>() with
        | true, ex when ex <> null ->
            let hello = ex.SayHello("World")
            let sum = ex.Add(3, 4)
            printfn "IExample.SayHello: %s" hello
            printfn "IExample.Add(3, 4): %d" sum
        | _ ->
            printfn "ERROR: IExample not found!"

        printfn ""
        let allExamples = TAppCentral.GetAllPlugins<IExample>()
        printfn "Plugins offering IExample: %d" allExamples.Count
        allExamples
        |> Seq.iteri (fun i ex ->
            let s = ex.SayHello("Plugin")
            printfn "  Plugin %d: %s" i s)

        printfn ""
        printfn "Teste Get<unbekannt>..."
        try
            TAppCentral.Get<IExampleParams>() |> ignore
            printfn "  -> unexpected: interface found"
        with
        | :? AppCentralInterfaceNotFoundException as ex ->
            printfn "  -> wie erwartet: %s" ex.Message

        printfn ""
        printfn "Shutdown..."
        TAppCentral.Shutdown()
        printfn "Done."
        0
