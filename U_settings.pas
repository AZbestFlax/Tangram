unit U_settings;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ColorGrd;

type
  TfrmSettings = class(TForm)
    Edit1: TEdit;
    Edit2: TEdit;
    Button1: TButton;
    Button2: TButton;
    CheckBox1: TCheckBox;
    ColorBox1: TColorBox;
    ColorBox2: TColorBox;
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmSettings: TfrmSettings;
  oldCol1, oldCol2: TColor;
  use_help: boolean;
implementation

uses
  U_tangram4, U_TPiece4;

{$R *.dfm}

procedure TfrmSettings.Button1Click(Sender: TObject);
begin
  Form1.RestartBtnClick(Self);
  Form1.Tangram.loadfigset(Form1.opendialog1.filename);
  Form1.Tangram.showfigure(Form1.tangram.curfig);
  Close;
end;

procedure TfrmSettings.Button2Click(Sender: TObject);
begin
  ColorBox1.Selected := oldCol1;
  ColorBox2.Selected := oldCol2;
  CheckBox1.Checked := use_help;
  Close;
end;

procedure TfrmSettings.FormActivate(Sender: TObject);
begin
  oldCol1 := ColorBox1.Selected;
  oldCol2 := ColorBox2.Selected;
  use_help := CheckBox1.Checked;
end;

procedure TfrmSettings.FormCreate(Sender: TObject);
begin
  ColorBox1.Items.Delete(0);
  ColorBox2.Items.Delete(0);
end;

end.
