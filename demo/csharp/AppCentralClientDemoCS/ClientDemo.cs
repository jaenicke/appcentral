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
using System.Runtime.InteropServices;
using AppCentralLib;

namespace AppCentralClientDemoCS
{
    [ComVisible(true), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("EA3B37D8-5603-42A9-AC5D-5AC9C70E165C")]
    public interface IAppDialogs
    {
        void ShowMessage(string message);
    }

    [ComVisible(true), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("9502D7C0-998E-4B4F-818D-866E786350C9")]
    public interface IDemoInfoInterface
    {
        string GetDisplayText(string info);
    }

    [ComVisible(true), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("EBF96CFD-0C3A-43B7-B576-94010511CBF2")]
    public interface IClientDemoInterface
    {
        IDemoInfoInterface GetInfo(string infoName);
    }

    [ComVisible(true), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("1BE3D2FA-2FFE-4B29-9FCF-4E1F9FD47C3D")]
    public interface IHostDemoInterface
    {
        int GetMagicNumber();
    }

    public class DemoInfoInterface : IDemoInfoInterface
    {
        private string infoName;

        public DemoInfoInterface(string infoName)
        {
            this.infoName = infoName;
        }

        public string GetDisplayText(string info)
        {
            string hostInfo;
            IHostDemoInterface hostInfoIntf;
            if (AppCentral.TryGet<IHostDemoInterface>(out hostInfoIntf))
                hostInfo = hostInfoIntf.GetMagicNumber().ToString();
            else
                hostInfo = "IHostDemoInterface not registered!";
            return $"Display text: {info} (powered by C# client DLL, {infoName})\r\nHost - magic number: {hostInfo}";
        }
    }

    public class DemoInterface : IClientDemoInterface
    {
        public IDemoInfoInterface GetInfo(string infoName)
        {
            return new DemoInfoInterface(infoName);
        }
    }

    public static class ClientDemo
    {
        [DllExport("RegisterAppCentralPlugin", CallingConvention = CallingConvention.StdCall)]
        static bool RegisterAppCentralPlugin(IAppCentral host, out IAppCentral client)
        {
            client = AppCentral.RegisterHost(host);
            AppCentral.Reg<IClientDemoInterface>(new DemoInterface());
            if (AppCentral.TryGet<IAppDialogs>(out IAppDialogs Dialogs))
                Dialogs.ShowMessage("Message from DLL: C# DLL registered!");
            return true;
        }
    }
}
