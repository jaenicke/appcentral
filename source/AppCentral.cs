/*
    *****BEGIN LICENSE BLOCK *****
    Version: MPL 1.1 / GPL 2.0 / LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1(the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL/

  Software distributed under the License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
  for the specific language governing rights and limitations under the
  License.

  The Original Code is AppCentral.

  The Initial Developer of the Original Code is Sebastian Jänicke.
  Portions created by the Initial Developer are Copyright(C) 2023
  the Initial Developer.All Rights Reserved.

  Contributor(s):
    none

  Alternatively, the contents of this file may be used under the terms of
  either the GNU General Public License Version 2 or later(the "GPL"), or
  the GNU Lesser General Public License Version 2.1 or later(the "LGPL"),
  in which case the provisions of the GPL or the LGPL are applicable instead
  of those above. If you wish to allow use of your version of this file only
  under the terms of either the GPL or the LGPL, and not to allow others to
  use your version of this file under the terms of the MPL, indicate your
  decision by deleting the provisions above and replace them with the notice
  and other provisions required by the GPL or the LGPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the MPL, the GPL or the LGPL.

  *****END LICENSE BLOCK *****
*/

using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace AppCentralLib
{
    public struct DelphiGuid
    {
        public int D1;
        public short D2;
        public short D3;
        public ulong _D4;

        public DelphiGuid(Guid systemGuid) : this()
        {
            byte[] data = systemGuid.ToByteArray();
            this.D1 = BitConverter.ToInt32(data, 0);            
            this.D2 = BitConverter.ToInt16(data, 4);
            this.D3 = BitConverter.ToInt16(data, 6);
            this._D4 = BitConverter.ToUInt64(data, 8);
        }

        public Guid ToGuid() => new Guid(D1, D2, D3, BitConverter.GetBytes(_D4));
    }


    [ComVisible(true),
        Guid("08C68342-3187-4D4A-AE93-96277FBA3CA3"),
        InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAppCentral
    {
        bool TryGet(bool AFromHost, DelphiGuid IntfGuid, [MarshalAs(UnmanagedType.IUnknown)] out object AInterface);
        void ShutdownPlugin();
    }

    [ComVisible(true)]
    public class AppCentral : IAppCentral
    {
        private static IAppCentral Instance = new AppCentral();
        private static IAppCentral HostInstance = null;
        private static Dictionary<Guid, object> Singletons = new Dictionary<Guid, object>();

        public bool TryGet(bool fromHost, DelphiGuid interfaceGuid, [MarshalAs(UnmanagedType.IUnknown)] out object targetInterface)
        {
            if (Singletons.TryGetValue(interfaceGuid.ToGuid(), out targetInterface))
                return true;
            if (HostInstance != null && !fromHost)
                return HostInstance.TryGet(false, interfaceGuid, out targetInterface);
            return false;
        }

        public void ShutdownPlugin()
        {
            HostInstance = null;
        }

        public static IAppCentral RegisterHost(IAppCentral host)
        {
            HostInstance = host;
            return Instance;
        }

        public static void Reg<T>(T singletonInstance) where T : class
        {
            if (singletonInstance != null)
            {
                Guid guid = typeof(T).GUID;
                Singletons[guid] = singletonInstance;
            }
        }

        public static void Unreg<T>() where T : class
        {
            Guid guid = typeof(T).GUID;
            Singletons.Remove(guid);
        }

        public static bool TryGet<T>(out T target) where T : class
        {
            DelphiGuid guid = new DelphiGuid(typeof(T).GUID);
            object result;
            if (Instance.TryGet(false, guid, out result) && result is T)
            {
                target = result as T;
                return true;
            }
            target = null;
            return false;
        }
    }
}
