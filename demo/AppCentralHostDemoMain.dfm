object frmAppCentralHostDemoMain: TfrmAppCentralHostDemoMain
  Left = 0
  Top = 0
  Caption = 'AppCentral demo'
  ClientHeight = 530
  ClientWidth = 700
  Color = clBtnFace
  Constraints.MinHeight = 568
  Constraints.MinWidth = 712
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  DesignSize = (
    700
    530)
  TextHeight = 15
  object Label1: TLabel
    Left = 8
    Top = 101
    Width = 684
    Height = 15
    Caption = 
      'You can load the demo plugin using this button. You will get an ' +
      'error message, if you do not register the hostinfo interface bef' +
      'ore.'
  end
  object Label2: TLabel
    Left = 8
    Top = 153
    Width = 682
    Height = 30
    Caption = 
      'The same functionality is available for C#. Both DLLs implement ' +
      'the same interface, so you can only load one. Of course each DLL' +
      ' could implement different interfaces.'
    WordWrap = True
  end
  object Label3: TLabel
    Left = 8
    Top = 220
    Width = 481
    Height = 15
    Caption = 
      'You can press the demo button at any time, but it won'#39't work bef' +
      'ore you load a plugin DLL.'
  end
  object Label5: TLabel
    Left = 8
    Top = 299
    Width = 300
    Height = 15
    Caption = 'You can load both plugins (Delphi, C#) using this button.'
  end
  object Label6: TLabel
    Left = 8
    Top = 351
    Width = 680
    Height = 15
    Caption = 
      'You can execute the function, which finds all attached plugin in' +
      'terfaces, at any time. It will find nothing before a plugin is l' +
      'oaded.'
  end
  object Label4: TLabel
    Left = 8
    Top = 8
    Width = 663
    Height = 30
    Caption = 
      'The DLL tries to retrieve an interface from the host application' +
      ' as well. You can register it here. Before you do so, you will g' +
      'et a message, that the interface can'#39't be found, when pressing t' +
      'he demo button.'
    WordWrap = True
  end
  object btnLoadPluginDelphi: TButton
    Left = 8
    Top = 122
    Width = 186
    Height = 25
    Caption = 'Load plugin (Delphi)'
    TabOrder = 0
    OnClick = btnLoadPluginDelphiClick
  end
  object btnLoadPluginCS: TButton
    Left = 8
    Top = 189
    Width = 186
    Height = 25
    Caption = 'Load plugin (C#)'
    TabOrder = 1
    OnClick = btnLoadPluginCSClick
  end
  object btnFirstDemo: TButton
    Left = 8
    Top = 241
    Width = 185
    Height = 25
    Caption = 'Demo function'
    TabOrder = 2
    OnClick = btnFirstDemoClick
  end
  object StaticText1: TStaticText
    Left = 8
    Top = 75
    Width = 419
    Height = 21
    Caption = 'Demo for getting one interface from any DLL, which implements it'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clBlack
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold, fsUnderline]
    ParentFont = False
    TabOrder = 3
  end
  object StaticText2: TStaticText
    Left = 8
    Top = 272
    Width = 328
    Height = 21
    Caption = 'Demo for getting all interfaces from all loaded DLLs'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clBlack
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold, fsUnderline]
    ParentFont = False
    TabOrder = 4
  end
  object btnLoadPlugins: TButton
    Left = 8
    Top = 320
    Width = 185
    Height = 25
    Caption = 'Load plugins'
    TabOrder = 5
    OnClick = btnLoadPluginsClick
  end
  object btnSecondDemo: TButton
    Left = 8
    Top = 372
    Width = 185
    Height = 25
    Caption = 'Execute second demo'
    TabOrder = 6
    OnClick = btnSecondDemoClick
  end
  object memResults: TMemo
    Left = 8
    Top = 403
    Width = 684
    Height = 119
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 7
  end
  object btnInitHostInterface: TButton
    Left = 8
    Top = 44
    Width = 185
    Height = 25
    Caption = 'Register hostinfo interface'
    TabOrder = 8
    OnClick = btnInitHostInterfaceClick
  end
end
