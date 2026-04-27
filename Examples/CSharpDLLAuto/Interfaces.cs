using System;
using System.Runtime.InteropServices.Marshalling;
using System.Runtime.InteropServices;

namespace AppCentralLib;

// IExample is declared here just like in the manual DLL project.
// safecall in Delphi/C++ = HRESULT + retval in COM = no [PreserveSig] in C#

[GeneratedComInterface(StringMarshalling = StringMarshalling.Custom,
    StringMarshallingCustomType = typeof(BStrStringMarshaller))]
[Guid("A1B2C3D4-E5F6-7890-ABCD-EF1234567890")]
public partial interface IExample
{
    string SayHello(string name);
    int Add(int a, int b);
}
