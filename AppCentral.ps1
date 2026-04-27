<#
.SYNOPSIS
  AppCentral host library for PowerShell.
.DESCRIPTION
  Dot-source this file to make the AppCentralPS.AppCentral class available:
      . path\to\AppCentral.ps1
      $ac = New-Object AppCentralPS.AppCentral

  All COM-interop logic is encapsulated in C# (Add-Type), because PowerShell
  automatically wraps COM objects as System.__ComObject - which prevents
  casting to custom interfaces.

  For each new custom interface a corresponding C# convenience method must
  be added to the AppCentral class below (see ExampleSayHello/ExampleAdd).
  
(*
 * Copyright (c) 2026 Sebastian Jänicke (github.com/jaenicke)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *)
#>

$Source = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace AppCentralPS
{
    [ComImport]
    [Guid("F7E8D9C1-B1A2-4E3F-8071-926354AABBCC")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAppCentralProvider
    {
        [PreserveSig]
        int GetInterface([MarshalAs(UnmanagedType.Bool)] bool fromHost,
            ref Guid iid,
            [MarshalAs(UnmanagedType.IUnknown)] object pParams,
            [MarshalAs(UnmanagedType.IUnknown)] out object obj);
        [PreserveSig]
        int Shutdown();
    }

    [ComImport]
    [Guid("A1B2C3D4-E5F6-7890-ABCD-EF1234567890")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IExample
    {
        [return: MarshalAs(UnmanagedType.BStr)]
        string SayHello([MarshalAs(UnmanagedType.BStr)] string name);
        int Add(int a, int b);
    }

    public class AppCentral
    {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr LoadLibraryW(string fileName);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr GetProcAddress(IntPtr hModule, [MarshalAs(UnmanagedType.LPStr)] string procName);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool FreeLibrary(IntPtr hModule);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate IntPtr RegisterHostDelegate(IntPtr hostProvider);

        private List<IAppCentralProvider> providers = new List<IAppCentralProvider>();
        private List<IntPtr> handles = new List<IntPtr>();
        private List<string> filenames = new List<string>();

        public bool LoadPlugin(string path)
        {
            IntPtr h = LoadLibraryW(path);
            if (h == IntPtr.Zero) return false;
            IntPtr proc = GetProcAddress(h, "RegisterHost");
            if (proc == IntPtr.Zero) { FreeLibrary(h); return false; }
            var fn = (RegisterHostDelegate)Marshal.GetDelegateForFunctionPointer(proc, typeof(RegisterHostDelegate));
            IntPtr providerPtr = fn(IntPtr.Zero);
            if (providerPtr == IntPtr.Zero) { FreeLibrary(h); return false; }
            var provider = (IAppCentralProvider)Marshal.GetObjectForIUnknown(providerPtr);
            Marshal.Release(providerPtr);
            providers.Add(provider);
            handles.Add(h);
            filenames.Add(path);
            return true;
        }

        public int PluginCount { get { return providers.Count; } }
        public string PluginFilename(int idx) { return filenames[idx]; }

        // Convenience: encapsulate all IExample calls fully in C#,
        // because PowerShell wraps COM objects as System.__ComObject without methods.

        public string ExampleSayHello(string name)
        {
            var ex = QueryExample();
            return ex == null ? null : ex.SayHello(name);
        }

        public int ExampleAdd(int a, int b)
        {
            var ex = QueryExample();
            return ex == null ? -1 : ex.Add(a, b);
        }

        private IExample QueryExample()
        {
            Guid iid = typeof(IExample).GUID;
            foreach (var p in providers)
            {
                object obj;
                int hr = p.GetInterface(true, ref iid, null, out obj);
                if (hr == 0 && obj != null) return (IExample)obj;
            }
            return null;
        }

        public string[] AllExamplesSayHello(string name)
        {
            var result = new List<string>();
            Guid iid = typeof(IExample).GUID;
            foreach (var p in providers)
            {
                object obj;
                int hr = p.GetInterface(true, ref iid, null, out obj);
                if (hr == 0 && obj != null)
                    result.Add(((IExample)obj).SayHello(name));
            }
            return result.ToArray();
        }

        public void Shutdown()
        {
            foreach (var p in providers)
            {
                try { p.Shutdown(); } catch { }
            }
            providers.Clear();
            // Release refs first, then FreeLibrary
            GC.Collect();
            GC.WaitForPendingFinalizers();
            foreach (var h in handles)
            {
                if (h != IntPtr.Zero) FreeLibrary(h);
            }
            handles.Clear();
        }
    }
}
"@

Add-Type -TypeDefinition $Source -Language CSharp
