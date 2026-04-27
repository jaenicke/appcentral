"""
Interface-Definitionen (Pendant zu AppCentral.Interfaces.pas / Interfaces.cs)
Must match the Delphi/C# declarations (same GUIDs, same methods).
"""

import ctypes

import comtypes
from comtypes import GUID, HRESULT, COMMETHOD, BSTR, IUnknown


class IExample(IUnknown):
    """
    Sample interface (identical to the Delphi/C# version).
    safecall in Delphi = HRESULT + retval in COM.
    """
    _iid_ = GUID('{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}')
    _methods_ = [
        COMMETHOD([], HRESULT, 'SayHello',
                  (['in'], BSTR, 'name'),
                  (['out', 'retval'], ctypes.POINTER(BSTR), 'pResult')),
        COMMETHOD([], HRESULT, 'Add',
                  (['in'], ctypes.c_int, 'a'),
                  (['in'], ctypes.c_int, 'b'),
                  (['out', 'retval'], ctypes.POINTER(ctypes.c_int), 'pResult')),
    ]


class IExampleParams(IUnknown):
    """Optional parameter interface for initialisation."""
    _iid_ = GUID('{B2C3D4E5-F6A7-8901-BCDE-F12345678901}')
    _methods_ = [
        COMMETHOD([], HRESULT, 'GetGreeting',
                  (['out', 'retval'], ctypes.POINTER(BSTR), 'pResult')),
    ]
