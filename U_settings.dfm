object frmSettings: TfrmSettings
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMaximize]
  BorderStyle = bsSingle
  Caption = #1053#1072#1083#1072#1096#1090#1091#1074#1072#1085#1085#1103
  ClientHeight = 144
  ClientWidth = 267
  Color = clSkyBlue
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnActivate = FormActivate
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Edit1: TEdit
    Left = 8
    Top = 8
    Width = 122
    Height = 21
    TabStop = False
    Alignment = taCenter
    ReadOnly = True
    TabOrder = 4
    Text = #1050#1086#1083#1110#1088' '#1087#1086#1083#1103
  end
  object Edit2: TEdit
    Left = 136
    Top = 8
    Width = 122
    Height = 21
    TabStop = False
    Alignment = taCenter
    ReadOnly = True
    TabOrder = 6
    Text = #1050#1086#1083#1110#1088' '#1092#1110#1075#1091#1088
  end
  object Button1: TButton
    Left = 8
    Top = 109
    Width = 122
    Height = 25
    Caption = #1054#1050
    TabOrder = 3
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 136
    Top = 109
    Width = 122
    Height = 25
    Caption = #1057#1082#1072#1089#1091#1074#1072#1090#1080
    TabOrder = 5
    OnClick = Button2Click
  end
  object CheckBox1: TCheckBox
    Left = 8
    Top = 72
    Width = 251
    Height = 17
    Caption = #1055#1086#1082#1072#1079#1091#1074#1072#1090#1080' '#1076#1086#1087#1086#1084#1110#1078#1085#1110' '#1083#1110#1085#1110#1111
    Color = clCream
    ParentColor = False
    TabOrder = 2
  end
  object ColorBox1: TColorBox
    Left = 8
    Top = 35
    Width = 122
    Height = 22
    DefaultColorColor = clRed
    Selected = clRed
    Style = [cbStandardColors]
    TabOrder = 0
  end
  object ColorBox2: TColorBox
    Left = 136
    Top = 35
    Width = 122
    Height = 22
    DefaultColorColor = clBlue
    Selected = clBlue
    Style = [cbStandardColors]
    TabOrder = 1
  end
end
