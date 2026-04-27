using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.Marshalling;

namespace AppCentralLib;

// ============================================================================
// IExample - sample interface (identical to the Delphi declaration)
// safecall in Delphi = HRESULT + retval in COM = no [PreserveSig] in C#
// ============================================================================

[GeneratedComInterface(StringMarshalling = StringMarshalling.Custom,
    StringMarshallingCustomType = typeof(BStrStringMarshaller))]
[Guid("A1B2C3D4-E5F6-7890-ABCD-EF1234567890")]
public partial interface IExample
{
    string SayHello(string name);
    int Add(int a, int b);
}

// ============================================================================
// IExampleParams - optional parameter interface
// ============================================================================

[GeneratedComInterface(StringMarshalling = StringMarshalling.Custom,
    StringMarshallingCustomType = typeof(BStrStringMarshaller))]
[Guid("B2C3D4E5-F6A7-8901-BCDE-F12345678901")]
public partial interface IExampleParams
{
    string GetGreeting();
}
