unit U_tangram4;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, extctrls, U_TPiece4, Menus, shellapi, ToolWin, ComCtrls, XPMan,
  Vcl.Buttons, U_settings;

type
  TForm1 = class(TForm)
    SaveDialog1: TSaveDialog;
    OpenDialog1: TOpenDialog;
    Panel1: TPanel;
    LoadPiecebtn: TButton;
    RestartBtn: TButton;
    NextBtn: TButton;
    SolveBtn: TButton;
    PrevBtn: TButton;
    ExitBtn: TButton;
    RoundBtn: TCheckBox;
    XPManifest1: TXPManifest;
    sbtnLoad: TSpeedButton;
    SpeedButton1: TSpeedButton;
    SpeedButton2: TSpeedButton;
    SpeedButton3: TSpeedButton;
    SpeedButton4: TSpeedButton;
    SpeedButton5: TSpeedButton;
    SpeedButton6: TSpeedButton;
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure RestartBtnClick(Sender: TObject);
    procedure NextBtnClick(Sender: TObject);
    procedure Open1Click(Sender: TObject);
    procedure LoadPiecebtnClick(Sender: TObject);
    procedure SolveBtnClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PrevBtnClick(Sender: TObject);
    procedure ExitBtnClick(Sender: TObject);
    procedure SpeedButton6Click(Sender: TObject);
  public
    Tangram:TTangram;
    figfile:string;
    procedure setcaption;
  end;

var
  Form1: TForm1;

implementation

{$R *.DFM}


{******************* Form Methods *******************}


{***************** FormActivate *************}
procedure TForm1.FormActivate(Sender: TObject);
begin
  Tangram:=TTangram.createTangram(self,rect(0,0,Screen.WorkAreaWidth-95,
                                  clientheight-40),false);
  doublebuffered:=true; {eliminate flicker}
  opendialog1.initialdir:=extractfilepath(application.exename);
  figfile:=opendialog1.InitialDir+'\OriginalSquare.tan';

  if fileexists(figfile) then
  with tangram do
  begin
    loadfigset(figfile);
    showfigure(1);
    setcaption;
    //solvebtnclick(sender);
  end
  else Open1click(self);  {get a figures file}

end;

{**************** FormClose **************}
procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
 tangram.Free;
end;

{**************** RestartBtnClck **********}
procedure TForm1.RestartBtnClick(Sender: TObject);
begin
  tangram.restart;
end;

{************ NextBtnClick ********}
procedure TForm1.NextBtnClick(Sender: TObject);
begin
  with tangram do showfigure(curfig+1);
  setcaption;
end;

{********** PrevBtnClick **********8}
procedure TForm1.PrevBtnClick(Sender: TObject);
begin
  with tangram do showfigure(curfig-1);
  setcaption;
end;

{*************** Open1Click ***********}
procedure TForm1.Open1Click(Sender: TObject);
begin

    if OpenDialog1.execute then
    with tangram do
    begin
      loadfigset(opendialog1.filename);
      figfile:=opendialog1.filename;
      showfigure(1);
      setcaption;
    end;
end;

{************ LoadPieceBtnClick ******}
procedure TForm1.LoadPiecebtnClick(Sender: TObject);
begin
  Open1click(sender);
end;

{************ SolveBtnClick ***********}
procedure TForm1.SolveBtnClick(Sender: TObject);
begin
   tangram.showsolution;
end;

procedure TForm1.SpeedButton6Click(Sender: TObject);
begin
  frmSettings.ShowModal;
end;

{*********** FormKeyDown *************}
procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  f:string;
begin
   with tangram do
   if (dragnbr>0) and ((key=ord('F')) or (key=ord('f')))
   then
   begin
     piece[dragnbr].flip;
     invalidate;
   end
   else if ((key=ord('S')) or (key=ord('s'))) then
   begin
     {save figure as a bitmap}
     b:=tbitmap.create;
     b.width:=tangram.width;
     b.height:=tangram.height;
     tangram.painttobitmap(b);
     f:=extractfilename(figfile);
     delete(f,pos('.',f),4);

     f:=extractfilepath(application.exename)+trim(f)+'_Fig'+inttostr(curfig)+'.bmp';
     b.savetofile(f);
     b.free;
   end;
end;

{********** SetCaption *********}
procedure TForm1.setcaption;
begin
  caption:='“¿Õ√–¿Ã - '+Uppercase(extractfilename(figfile))+',  ‘≥„Û‡ '+inttostr(tangram.curfig)
           + ' Á '+ inttostr(tangram.nbrfigures);
end;

{*********** ExitBtnClick *********}
procedure TForm1.ExitBtnClick(Sender: TObject);
begin
  close;
end;

end.

