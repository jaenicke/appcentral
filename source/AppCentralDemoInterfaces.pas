{
  ***** BEGIN LICENSE BLOCK *****
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1 (the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL/

  Software distributed under the License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
  for the specific language governing rights and limitations under the
  License.

  The Original Code is AppCentral.

  The Initial Developer of the Original Code is Sebastian Jänicke.
  Portions created by the Initial Developer are Copyright (C) 2023
  the Initial Developer. All Rights Reserved.

  Contributor(s):
    none

  Alternatively, the contents of this file may be used under the terms of
  either the GNU General Public License Version 2 or later (the "GPL"), or
  the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
  in which case the provisions of the GPL or the LGPL are applicable instead
  of those above. If you wish to allow use of your version of this file only
  under the terms of either the GPL or the LGPL, and not to allow others to
  use your version of this file under the terms of the MPL, indicate your
  decision by deleting the provisions above and replace them with the notice
  and other provisions required by the GPL or the LGPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the MPL, the GPL or the LGPL.

  ***** END LICENSE BLOCK *****
}

unit AppCentralDemoInterfaces;

interface

type
  IAppDialogs = interface
  ['{EA3B37D8-5603-42A9-AC5D-5AC9C70E165C}']
    procedure ShowMessage(const AMessage: WideString); safecall;
  end;

  IDemoInfoInterface = interface
  ['{9502D7C0-998E-4B4F-818D-866E786350C9}']
    function GetDisplayText(const AInfo: WideString): WideString; safecall;
  end;

  IClientDemoInterface = interface
  ['{EBF96CFD-0C3A-43B7-B576-94010511CBF2}']
    function GetInfo(const AInfoName: WideString): IDemoInfoInterface; safecall;
  end;

  IHostDemoInterface = interface
  ['{1BE3D2FA-2FFE-4B29-9FCF-4E1F9FD47C3D}']
    function GetMagicNumber: LongInt; safecall;
  end;

implementation

end.
