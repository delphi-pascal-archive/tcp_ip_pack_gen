object Form1: TForm1
  Left = 216
  Top = 126
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'TCP/IP Packet Generator'
  ClientHeight = 605
  ClientWidth = 662
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 120
  TextHeight = 16
  object TopPanel: TPanel
    Left = 0
    Top = 0
    Width = 662
    Height = 80
    Align = alTop
    TabOrder = 0
    object Label1: TLabel
      Left = 81
      Top = 16
      Width = 163
      Height = 16
      Caption = 'Number of packets to send:'
    end
    object Label2: TLabel
      Left = 75
      Top = 46
      Width = 172
      Height = 16
      Caption = 'Delay between sends, msec:'
    end
    object NumPacketsEdit: TEdit
      Left = 262
      Top = 10
      Width = 60
      Height = 24
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -17
      Font.Name = 'Courier New'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      Text = '1'
    end
    object DelayEdit: TEdit
      Left = 262
      Top = 39
      Width = 60
      Height = 24
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -17
      Font.Name = 'Courier New'
      Font.Style = []
      ParentFont = False
      TabOrder = 1
      Text = '1000'
    end
    object GoButton: TButton
      Left = 416
      Top = 24
      Width = 233
      Height = 25
      Caption = 'Generate Packets'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clRed
      Font.Height = -15
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
      TabOrder = 2
      OnClick = GoButtonClick
    end
  end
  object MainPanel: TPanel
    Left = 0
    Top = 80
    Width = 662
    Height = 364
    Align = alTop
    TabOrder = 1
    object GroupBox2: TGroupBox
      Left = 10
      Top = 10
      Width = 641
      Height = 90
      Caption = ' IP Settings '
      TabOrder = 0
      object SrcIPLabel: TLabel
        Left = 43
        Top = 26
        Width = 61
        Height = 16
        Caption = 'Source IP:'
      end
      object DstIPLabel: TLabel
        Left = 20
        Top = 55
        Width = 85
        Height = 16
        Caption = 'Destination IP:'
      end
      object TTLLabel: TLabel
        Left = 489
        Top = 26
        Width = 82
        Height = 16
        Caption = 'Time To Live:'
      end
      object DstIpEdit: TEdit
        Left = 108
        Top = 49
        Width = 218
        Height = 24
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -17
        Font.Name = 'Courier New'
        Font.Style = []
        ParentFont = False
        TabOrder = 1
        Text = '192.168.222.222'
      end
      object SrcIpEdit: TEdit
        Left = 108
        Top = 20
        Width = 218
        Height = 24
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -17
        Font.Name = 'Courier New'
        Font.Style = []
        ParentFont = False
        TabOrder = 0
        Text = '192.168.111.111'
      end
      object TtlEdit: TEdit
        Left = 581
        Top = 20
        Width = 50
        Height = 24
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -17
        Font.Name = 'Courier New'
        Font.Style = []
        MaxLength = 3
        ParentFont = False
        TabOrder = 4
        Text = '128'
      end
      object RandomSrcIP: TCheckBox
        Left = 335
        Top = 20
        Width = 119
        Height = 21
        Alignment = taLeftJustify
        Caption = 'Use Random ->'
        TabOrder = 2
        OnClick = RandomSrcIPClick
      end
      object RandomDstIP: TCheckBox
        Left = 335
        Top = 49
        Width = 119
        Height = 21
        Alignment = taLeftJustify
        Caption = 'Use Random ->'
        TabOrder = 3
        OnClick = RandomDstIPClick
      end
    end
    object TabControl: TTabControl
      Left = 10
      Top = 108
      Width = 641
      Height = 248
      TabOrder = 1
      Tabs.Strings = (
        'TCP Settings'
        'UDP Settings'
        'ICMP/Ping Settings')
      TabIndex = 0
      OnChange = TabControlChange
      object SrcPortLabel: TLabel
        Left = 32
        Top = 47
        Width = 73
        Height = 16
        Alignment = taRightJustify
        Caption = 'Source Port:'
      end
      object DstPortLabel: TLabel
        Left = 8
        Top = 76
        Width = 97
        Height = 16
        Alignment = taRightJustify
        Caption = 'Destination Port:'
      end
      object SeqNoLabel: TLabel
        Left = 30
        Top = 106
        Width = 75
        Height = 16
        Alignment = taRightJustify
        Caption = 'Sequence #:'
      end
      object SrcPortEdit: TEdit
        Left = 116
        Top = 41
        Width = 169
        Height = 24
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -17
        Font.Name = 'Courier New'
        Font.Style = []
        ParentFont = False
        TabOrder = 0
        Text = '80'
      end
      object DstPortEdit: TEdit
        Left = 116
        Top = 70
        Width = 169
        Height = 24
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -17
        Font.Name = 'Courier New'
        Font.Style = []
        ParentFont = False
        TabOrder = 1
        Text = '80'
      end
      object SequenceEdit: TEdit
        Left = 116
        Top = 100
        Width = 169
        Height = 24
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -17
        Font.Name = 'Courier New'
        Font.Style = []
        ParentFont = False
        TabOrder = 2
        Text = '123456789'
      end
      object FlagsGroupBox: TGroupBox
        Left = 492
        Top = 39
        Width = 139
        Height = 90
        Caption = 'Flags'
        TabOrder = 6
        object FinFlag: TCheckBox
          Left = 10
          Top = 20
          Width = 50
          Height = 21
          Caption = 'FIN'
          TabOrder = 0
        end
        object SynFlag: TCheckBox
          Left = 10
          Top = 39
          Width = 60
          Height = 21
          Caption = 'SYN'
          Checked = True
          State = cbChecked
          TabOrder = 1
        end
        object RstFlag: TCheckBox
          Left = 10
          Top = 59
          Width = 60
          Height = 21
          Caption = 'RST'
          TabOrder = 2
        end
        object PshFlag: TCheckBox
          Left = 69
          Top = 20
          Width = 60
          Height = 21
          Caption = 'PSH'
          TabOrder = 3
        end
        object AckFlag: TCheckBox
          Left = 69
          Top = 39
          Width = 60
          Height = 21
          Caption = 'ACK'
          TabOrder = 4
        end
        object UrgFlag: TCheckBox
          Left = 69
          Top = 59
          Width = 60
          Height = 21
          Caption = 'URG'
          TabOrder = 5
        end
      end
      object RandomSrcPort: TCheckBox
        Left = 294
        Top = 47
        Width = 119
        Height = 21
        Alignment = taLeftJustify
        Caption = 'Use Random ->'
        TabOrder = 3
        OnClick = RandomSrcPortClick
      end
      object RandomDstPort: TCheckBox
        Left = 294
        Top = 77
        Width = 119
        Height = 21
        Alignment = taLeftJustify
        Caption = 'Use Random ->'
        TabOrder = 4
        OnClick = RandomDstPortClick
      end
      object UseRandomSeq: TCheckBox
        Left = 294
        Top = 106
        Width = 119
        Height = 21
        Alignment = taLeftJustify
        Caption = 'Use Random ->'
        TabOrder = 5
        OnClick = UseRandomSeqClick
      end
      object DataMemo: TMemo
        Left = 8
        Top = 148
        Width = 623
        Height = 90
        Lines.Strings = (
          'Data to send')
        TabOrder = 7
      end
    end
  end
  object ResultMemo: TMemo
    Left = 0
    Top = 444
    Width = 662
    Height = 161
    Align = alClient
    Ctl3D = False
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -15
    Font.Name = 'Courier New'
    Font.Style = []
    Lines.Strings = (
      'Results Window...')
    ParentCtl3D = False
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 2
  end
end
