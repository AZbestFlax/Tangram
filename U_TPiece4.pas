Unit U_TPiece4;

interface

uses windows, classes, sysutils, graphics, controls, extctrls, forms, dialogs,
      math, U_settings;

const
  maxpoints=5; {maximum nbr of points in a single tangram piece}
type
  tline=record
    p1,p2:TPoint;
  end;

  type Trealpoint =record
       x,y:single;
     end;

  tpiece = class(TObject)       {TPIECE - Tangram piece class}
    public
      points:array [1..maxpoints] of TRealPoint;   {make dynamic later}
      drawpoints:array[1..maxpoints] of TPoint; {make dynamic later}
      drawcenter:TPoint;
      center,offset:TRealPoint;
      nbrpoints:integer;
      piececolor:TColor;
      gridsize:integer;
      angle:integer;  {0..7, angle in 45 degree units}
      dragging:boolean;
      movable:boolean;  {can be moved (figure outlines are unmovable)}
      visible:boolean;
      piecenbr:integer;

      procedure assign(p:TPiece);
      procedure rotate45(n:integer);                           
      procedure moveby(p:TrealPoint);
      procedure moveto(p:TRealPoint);
      procedure makedrawpoints;
      procedure draw(canvas:TCanvas);
      procedure flip;
      {PointInPoly helps recognize mouse clicks and solutions }
      function pointinpoly(p:TPoint):Integer;
  end;


 tfigpoint=record   {defines center point of a piece in a figure}
    exists:boolean;
    x,y:integer;
    r,f:integer; {r - amt to rotate, f = 1=mirror flip}
    pcolor:TColor;
    piecenbr:integer;
  end;

  Tfigpieces=class(TObject)  {array defining figure piece characteristics}
      fig:array of tfigpoint;
    end;

  tTangram=class(TPaintbox)
  protected
     procedure Paint;   override;
     procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
                         X, Y: Integer); override;
     procedure MouseMove(Shift: TShiftState; X,Y: Integer); override;
  public
     piecesfilename:string;
     figfilename:string;
     piece: array of TPiece; {array of piece shapes, locations, colors, orientations}
     homepiece:array of Tpiece; {initial piece location info}
     figures:array of Tfigpieces;  {a set of figures, one is active at a time}
     solutionpieces:array of TPiece;  {pieces in the solution figure}
     piecesInplace:integer; {count of pieces placed - used to recognize solved state}
     nbrpieces, nbrfigures:integer;
     curfig:integer;  {the figure currently being solved, indexed from 1}
     dragnbr:integer; {which piece is selected}
     gridsize:integer;  {multiplier for grid}
     sizestep: Byte;
     splitpoint:integer;  {x coordinate divider beween figures and pieces home}
     editmode:boolean;  {maybe useful for if edit is implemented}
     b:TBitmap;
     drawdragged:boolean;
     constructor createTangram(aowner:TWinControl; newsize:TRect;
                               neweditMode:boolean);
     destructor destroy;  override;
     function  loadpieces(fname:string):boolean;
     procedure loadfigset(fname:string);
     procedure addpiece(p:TPiece);
     procedure restart;
     procedure showfigure(fignbr:integer);
     function pieceInSolution:boolean;
     procedure showsolution;
     procedure painttobitmap(b:TBitmap);

  end;


  const
  {selectable colors for testing}
  colors:array[0..11] of tcolor=
  (clblue,clred,clyellow,clgreen,clpurple, cllime,
   clfuchsia,claqua,clteal,clNavy,clmaroon,clolive);


implementation

uses U_tangram4;

var
  {Due to a design problem, the area of the pieces changes under rotation}
  {As a result, all of the pieces may be fit into some of figures with some
   white space left over.}
  {This table contains the area size changes when default positions are rotated
   an odd number of times.}
  {The program now calculates the sum of the rotation area effect for both the
   target figure and the pieces dropped on the figure area.  If the puzzle
   appears to be solved but the two area adjustment sums do not match, a Try
   again message is given instead of the "solved" message}
  parityAdjust:array[1..7] of integer=(-4,+2,+2,+8,+8,-4,-4);


  {******************* LOCAL SUBROUTINES **********************}

  function realpoint(x,y:integer):TRealPoint; overload;
  begin
    result.x:=x;
    result.y:=y;
  end;

  function realpoint(x,y:single):TRealPoint;  overload;
  begin
    result.x:=x;
    result.y:=y;
  end;

  function realpoint(p:TPoint):TRealPoint;  overload;
  begin
    result.x:=p.x;
    result.y:=p.y;
  end;




  {**************** SameSide ***************}
  function sameside(L:TLine; p1,p2:TPoint; var pointonborder:boolean):int64;
  {used by Intersect function}
  {same side =>result>0
   opposite sides => result <0
   a point on the line => result=0 }
  var
    dx,dy,dx1,dy1,dx2,dy2:int64;
  begin
    dx:=L.p2.x-L.P1.x;
    dy:=L.p2.y-L.P1.y;
    dx1:=p1.x-L.p1.x;
    dy1:=p1.y-L.p1.y;
    dx2:=p2.x-L.p2.x;
    dy2:=p2.y-L.p2.y;
    result:=(dx*dy1-dy*dx1)*(dx*dy2-dy*dx2);
    if ((dx<>0) or (dy<>0)) and (result=0) then pointonborder:=true
    else pointonborder:=false;
  end;

  {***************** SLOPE *****************}
  function slope(L:TLine):extended;
  {return slope of a line}
  begin
    with L do
    begin
      if p1.x<>p2.x then  result:=round(10*((p2.y-p1.y)/(p2.x-p1.x)))
      else result:=1e10;
    end;
  end;

  {******************** INTERSECT *******************}
  function  intersect(L1,L2:TLine; var pointonborder,colinear:boolean):boolean;
  {test for 2 lines intersecting }
  var
    a,b:int64;
    pb:boolean;
  begin
    pointonborder:=false;
    colinear:=false;
    a:=sameside(L1,L2.p1,L2.p2, pb);
    if pb then pointonborder:=true;
    b:=sameside(L2,L1.p1,L1.p2,pb);
    if pb then pointonborder:=true;
    result:=(a<=0) and (b<=0);
    if result then if slope(L1)=slope(L2) then colinear:=true;
  end;

  {**************** OVERLAPPED *******************}
  function overlapped(L1,L2:TLine):boolean;
  {Do these  co-linear lines overlap?}
  var
    L:TLine;
    P:TPoint;
  begin
    result:=false;
    if L1.p1.y<>L1.p2.y then  {not horizontal}
    begin
      with L1 do   {sort by y}
      If p1.y>p2.y then
      begin
        p:=p1;
        p1:=p2;
        p2:=p;
      end;
      with L2 do
      If p1.y>p2.y then
      begin
        p:=p1;
        p1:=p2;
        p2:=p;
      end;
      If L1.P1.Y>L2.P1.Y then  {sort lines by Y}
      begin
        L:=L1;
        L1:=L2;
        L2:=L;
      end;
      {2nd point of L1 must be > 1st point of L2}
      if L1.p2.y>L2.p1.y then result:=true;
    end
    else
    begin {horizontal - use X for comaprisons}
      with L1 do   {sort by x}
      If p1.x>p2.x then
      begin
        p:=p1;
        p1:=p2;
        p2:=p;
      end;
      with L2 do
      If p1.x>p2.x then
      begin
        p:=p1;
        p1:=p2;
        p2:=p;
      end;
      If L1.P1.x>L2.P1.x then  {sort lines by x}
      begin
        L:=L1;
        L1:=L2;
        L2:=L;
      end;
      {for overlap, rightmost point of L1 be be greater then leftmost of L2}
      if L1.p2.x>L2.p1.x then result:=true;
    end;
  end;

{**************** TPiece.assign *************}
procedure TPiece.assign(p:TPiece);
{assign piece p to ourselves}
var
  i:integer;
begin
  nbrpoints:=p.nbrpoints;
  for i:= 1 to nbrpoints do
  begin
    points[i]:=p.points[i];
    drawpoints[i]:=p.drawpoints[i];
  end;
  center:=p.center;
  drawcenter:=p.drawcenter;
  piececolor:=p.piececolor;
  angle:=p.angle;
  gridsize:=p.gridsize;
  dragging:=false;
  movable:=p.movable;
  offset:=p.offset;
  visible:=p.visible;
  piecenbr:=p.piecenbr;
end;


{*************** TPiece.draw **************}
procedure tpiece.draw(canvas:TCanvas);
begin
  if visible then
  with canvas do
  begin
    if dragging then pen.width:=2
    else pen.width:=1;
    {can't draw the border in black if we are drawing in order to
     check for overlapping pieces}
    pen.color:=clWhite;   //колір контуру частини
    brush.color:=piececolor;
    polygon(slice(drawpoints,nbrpoints));
  end;
end;


const {PointInPoly result values}
  PPoutside=1;
  PPInside=2;
  PPVertex=3;
  PPEdge=4;



 {************* PointInPoly *************}
function TPiece.PointInPoly(p:TPoint):integer;
{Version for convex polygons only - if we traverse around the polygon and
 and the point is on the same side of each edge, it must be inside}

{ result values:
    1 ==> Outside  (PPOutside)
    2 ==> Inside   (PPInside)
    3 ==> Vertex   (PPVertex)
    4 ==> Edge    (PPEdge)
 }

 var
  i:integer;
  n,np:int64;
  lp:TLine;

     function side(L:TLine; p:TPoint):int64;
     {
      result>0 if point on right side of line
      result<0 if point on left side of line
      result=0 if on (or colineear with) line
      }
      begin
         result:=(p.y - L.P1.y) * (L.P2.x - L.P1.x)
                  - (p.x - L.P1.x) * (L.P2.y - L.P1.y);
      end;

      function between(p1,p2,p3:TPoint):boolean;
      {result = true if p1 between p2 and p3}
      begin
        if     (p1.x<=max(p2.x,p3.x)) and (p1.x>=min(p2.x,p3.x))
           and (p1.y<=max(p2.y,p3.y)) and (p1.y>=min(p2.y,p3.y))
        then result:=true
        else result:=false;
      end;


  begin
    result:=PPInside;
    nP:=0;
    for i:=1 to nbrpoints do
    begin
      {is it a vertex?}
      if (p.x=drawpoints[i].x) and (p.y=drawpoints[i].y) then
      begin
        result:=PPVertex;
        break;
      end;
      lp.p1:=drawpoints[i];
      If i<nbrpoints then lp.p2:=drawpoints[i+1] else lp.p2:=drawpoints[1];

      n:=side(lp,p);  {which side of edge?}
      if (n=0) then  {on or in line with edge}
      begin
        if between(p,lp.p1,lp.p2) then   {vertex or interior to line}
          {make sure the next point is not a vertex}
          if (lp.p2.x=p.x) and (lp.p2.y=p.y) then result:=ppVertex
          else result:=PPEdge
        else result:=PPOutside;    {in line but noit betweeen ==> outside}
        break;
      end;
      if n*np<0 then {same side as for previous edge?}
      begin
        result:=PPoutside;
        break;
      end;
      np:=n; {save side as previous side for next edge test}
    end;
  end;



  (*
{**************** TPiece.rotate45 ******************}
procedure TPiece.Introtate45;

    procedure rotate(var p:Tpoint; a:real);
     {rotate point "p" by "a" radians about the origin (0,0)}
     var
       t:TPoint;
     Begin
       t:=P;
       p.x:=round(t.x*cos(a)-t.y*sin(a));
       p.y:=round(t.x*sin(a)+t.y*cos(a));
     end;

     procedure translate(var p:TPoint; t:TPoint);
     {move point "p" by x & y amounts specified in "t"}
     Begin
       p.x:=p.x+t.x;
       p.y:=p.y+t.y;
     end;

var
  i:integer;
begin
  angle:=(angle +1) mod 8;
  for i:= 1 to nbrpoints do
  begin
    translate(points[i],point(-center.x,-center.y));
    rotate(points[i],pi/4.0);
    translate(points[i],center);
  end;
  makedrawpoints;
end;
*)



procedure TPiece.rotate45(n:integer);

    procedure rotate(var p:Trealpoint; a:real);
     {rotate point "p" by "a" radians about the origin (0,0)}
     var
       t:TrealPoint;
     Begin
       t:=P;
       p.x:=t.x*cos(a)-t.y*sin(a);
       p.y:=t.x*sin(a)+t.y*cos(a);
       if form1.roundbtn.checked then
       begin
         p.x:=round(p.x);
         p.y:=round(p.y);
       end;
     end;

     procedure translate(var p:TrealPoint; t:TRealPoint);
     {move point "p" by x & y amounts specified in "t"}
     Begin
       p.x:=p.x+t.x;
       p.y:=p.y+t.y;
       if form1.roundbtn.checked then
       begin
         p.x:=round(p.x);
         p.y:=round(p.y);
       end;
     end;

var
  i:integer;
  preal,centerreal:TRealpoint;
begin
  angle:=(angle+n) mod 8;
  for i:= 1 to nbrpoints do
  begin
    preal.x:=points[i].x;
    preal.y:=points[i].y;
    centerreal.x:=-center.X;
    centerreal.y:=-center.y;
    translate(preal,centerreal);
    rotate(preal,n*pi/4.0);
    centerreal.x:=center.x;
    centerreal.y:=center.y;
    translate(preal,centerreal);
    points[i].x:=(preal.x);
    points[i].y:=(preal.y);
  end;
  makedrawpoints;
end;


{**************** Tpiece.Moveby ****************}
Procedure TPiece.moveby(P:TrealPoint);
{move piece by p.x and p.y}
var
  i:integer;
begin
  if form1.roundbtn.checked then
  begin
    for i:= 1 to nbrpoints do
    with points[i] do
    begin
      x:=round(x+p.X); //(x,p.x);
      y:=round(y+p.Y); //(y,p.y);
    end;
    with center do
    begin
      x:=round(x+p.X); //(x,p.x);
      y:=round(y+p.Y); //(y,p.y);
    end;
  end
  else
  begin
    for i:= 1 to nbrpoints do
    with points[i] do
    begin
      x:=(x+p.X); //(x,p.x);
      y:=(y+p.Y); //(y,p.y);
    end;
    with center do
    begin
      x:=(x+p.X); //(x,p.x);
      y:=(y+p.Y); //(y,p.y);
    end;
  end;

  makeDrawpoints;
end;

  {**************** Tpiece.Moveto ****************}
  Procedure TPiece.moveto(P:TRealPoint);
  {move piece to loc centered at p.x and p.y}
  begin
    moveby(realpoint(p.x-center.x, p.y-center.y));
  end;

  {***************** Tpiece.makedrawpoints *************}
  procedure TPiece.makedrawpoints;
  {Precalc screen positions to improve redraw speed}
  var
    i:integer;
  begin
    for i:= 1 to nbrpoints do
    begin
      drawpoints[i].x:=round(points[i].x*gridsize+offset.x);
      drawpoints[i].y:=round(points[i].y*gridsize+offset.y);
    end;
    drawcenter.x:=round(center.x*gridsize+offset.x);
    drawcenter.y:=round(center.y*gridsize+offset.y);
  end;

procedure TPiece.flip;
var
  i:integer;
begin
  for i:= 1 to nbrpoints do
  with points[i] do x:=2*center.x-x;
  makedrawpoints;
end;




 {*************************************************}
 {***************** tTangram methods **************}
 {*************************************************}

{************ TTangram,Paint ****************}
procedure TTangram.Paint;
var i:integer;
begin
  with canvas do
  begin
    brush.color:=color;
    pen.color:=clgray;
    pen.width:=2;
    rectangle(cliprect{clientrect});
    moveto(splitpoint,0);
    lineto(splitpoint,height);
  end;

  if curfig>0 then
  with canvas do
  begin
    brush.color:=frmSettings.ColorBox1.Selected;
    if frmSettings.CheckBox1.Checked then pen.color:=clgray else
    pen.color:=frmSettings.ColorBox1.Selected;
    pen.width:=1;
    for i:= 0 to high(solutionpieces) do
    with  solutionpieces[i] do
    begin
      polygon(slice(drawpoints,nbrpoints));
    end;
  end;
  {start with high pieces to draw unmovables first}

  for i:= high(piece) downto low(piece) do
    if assigned(piece[i])and (i<>dragnbr)
    then piece[i].draw(canvas);
  {make sure that selected piece shows on top}

  {drawdragged is set to false while dropping a piece  to allow
   checking for overlaps with underlying colors}
  if (dragnbr>=0) and drawdragged  then piece[dragnbr].draw(self.canvas);
end;




procedure TTangram.PaintToBitMap(b:TBitmap);
vaR
  i:integer;
begin
  with b, canvas do
  begin
    pixelformat:=pf24bit;
    brush.color:=clwhite;
    pen.color:=clwhite;
    pen.width:=1;
    for i:= 0 to high(solutionpieces) do
    with  solutionpieces[i] do
    begin
      polygon(slice(drawpoints,nbrpoints));
    end;
  end;
  for i:= high(piece) downto low(piece) do
    if assigned(piece[i])and (i<>dragnbr)
    then piece[i].draw(b.canvas);
  if (dragnbr>=0) and drawdragged then piece[dragnbr].draw(b.canvas);
end;



{**************** tTangram.Mousedown ******************}
procedure TTangram.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  i,r:integer;
  p:TPoint;
  inplacesum, figsum:integer;

  {------------ Show -----------}
  procedure show(msg:string; p:TPiece);
  {display location data for debugging}
        var
          j:integer;
          s,ds:string;
        begin
          (*  {for debugging}
          with form1.memo1.lines, p do
          begin
            add( msg );
            s:='Pts: ';
            ds:='Len: ';
            for j:=1 to nbrpoints do
            begin
              s:=s+ format('(%.2f, %.2f) ',[points[j].x, points[j].y]);

              if j>1 then
              with points[j-1] do
              ds:=ds+format('(%.2f) ',[sqrt(sqr(x-points[j].X)+
                    sqr(y-points[j].y))])
              else with points[nbrpoints] do
              ds:=ds+format('(%.2f) ',[sqrt(sqr(x-points[j].X)+
                    sqr(y-points[j].y))]);
            end;
            add('Points');
            add(s);
            add(ds);
            s:='';
            ds:='';
            for j:=1 to nbrpoints do
            begin
              s:=s+ format('(%d,%d) ',[drawpoints[j].x, drawpoints[j].y]);

              if j>1 then
              with drawpoints[j-1] do
              ds:=ds+format('L: (%.2f) ',[sqrt(sqr(x-drawpoints[j].X)+
                    sqr(y-drawpoints[j].y))])
              else with drawpoints[nbrpoints] do
              ds:=ds+format('L: (%.2f) ',[sqrt(sqr(x-drawpoints[j].X)+
                    sqr(y-drawpoints[j].y))]);
            end;
            add('DrawPoints');
            add(s);
            add(ds);
          end;
          *)
        end;


begin {mousedown}
  if dragnbr<0 then  {not dragging, is mouse on a piece?}
  Begin
    for i:= low(piece) to high(piece) do
    if assigned(piece[i]) and (piece[i].movable) then
    begin
      r:= piece[i].pointinpoly(point(x,y));
      if r=ppinside then
      with piece[i] do
      begin
        p:=clienttoscreen(drawcenter);
        setcursorpos(p.x,p.y);
        dragnbr:=i;
        dragging:=true;
        if drawcenter.x<splitpoint then dec(PiecesInPlace);
        if button = mbright  then
        begin
          rotate45(1);
          show('Поворот на 45',piece[i]);
        end
        else
        begin
          //form1.Memo1.clear;
          show('Обрана частина '+inttostr(i), piece[i]);
        end;

        invalidate;
        break;
      end;
    end;
  end
  else
  case button of
    mbleft:
      begin
        if editmode then
        begin
          piece[dragnbr].dragging:=false;
          invalidate;
          dragnbr:=-1;
        end
        else
        begin  {in play mode, dropping locations are restricted}
          If PieceInSolution then
          begin
            piece[dragnbr].dragging:=false;
            inc(PiecesinPlace);
            invalidate;
            dragnbr:=-1;            

            if (PiecesInplace=high(solutionpieces)+1) then
            begin
              InPlaceSum:=0;
              for i:= 0 to high(piece) do
              with Piece[i] do
              begin
                if angle mod 2 <> 0 then inc(InPlaceSum,parityadjust[piecenbr]);
              end;

              figsum:=0;
              for i:= 0 to high(figures[curfig-1].fig) do
              with figures[curfig-1].fig[i] do
              begin
                if r mod 2 <> 0 then inc(figsum,parityadjust[piecenbr]);
              end;

              If inplacesum=figsum
              then showmessage ('Чудово!')
              else showmessage('ОЙ. Майже вийшло.'
                        +#13 + 'Спробуйте знову!');
            end;
          end
          else
          If piece[dragnbr].drawcenter.x>splitpoint then
          begin
            piece[dragnbr].assign(homepiece[dragnbr]);
            invalidate;
            dragnbr:=-1;
          end
          else beep;
        end;
      end;
    mbright:
      begin
        piece[dragnbr].rotate45(1);
        show('Поворот на 45', piece[dragnbr]);
        invalidate;
      end;
  end; {case}
end;

{********************* tTangram.MouseMove **************}
procedure TTangram.MouseMove(Shift: TShiftState; X,Y: Integer);
var
  nx,ny:integer;
begin
  If (dragnbr>=0) then
  with piece[dragnbr] do
  if  (abs(x-drawcenter.x)>gridsize) or  (abs(y-drawcenter.y)>gridsize) then
  begin
    nx:=((x-drawcenter.x) div (gridsize));
    ny:=((y-drawcenter.y) div (gridsize));
    moveby(realpoint(nx,ny));
    invalidate;
  end;
end;

{******************** tTangram.CreateTangram *******************}
constructor TTangram.createTangram(aowner:TWinControl; newsize:TRect;
                                     neweditmode:boolean );
begin
  randomize;
  inherited create(aowner);
  parent:=aowner;
  left:= newsize.left;
  top:=newsize.top;
  width:=newsize.right-left;
  height:=newsize.bottom-top;
  editmode:=neweditmode;
  nbrpieces:=0;
  setlength(piece,0);
  setlength(homepiece,0);
  dragnbr:=-1;
  splitpoint:= (2*width) div 3;  {Split 2/3 of the way from left edge}
  gridsize:= (width-splitpoint) div 20{20 instead of 18 to do wide screen scaling};
  sizestep := 5;
  splitpoint:= gridsize* (splitpoint div gridsize); {put it on a grid boundary}
  b:=TBitmap.create;
  b.height:=height;
  b.width:=width;
  invalidate;
end;


{******************* tTangram.destroy ************}
destructor TTangram.destroy;
var
  i:integer;
begin
  for i:= low(piece) to high(piece) do piece[i].free;
  for i:= low(homepiece) to high(homepiece) do homepiece[i].free;
  setlength(piece,0);
  setlength(homepiece,0);
  inherited;
end;


{******************* tTangram.LoadPieces **************}
function TTangram.Loadpieces(fname:string):boolean;
{Load a piece definition file}
var
  f:textfile;
  i,j:integer;
  topx,topy,newrotate,newflip:integer;
  newx,newy:integer;
  {version:integer; }
  piececount, pointcount:integer;
begin
   if fileexists(fname) then
   begin
     result:=true;
     for i:= low(piece) to high(piece) do piece[i].free;
     for i:= low(homepiece) to high(homepiece) do homepiece[i].free;
     nbrpieces:=0;
     assignfile(f,fname);
     reset(f);
     readln(f {,version});
     readln(f,piececount);
     setlength(piece,piececount);
     for i:= 0 to piececount-1 do
     begin
       readln(f);
       inc(nbrpieces);
       piece[i]:=TPiece.create;
       with piece[i] do
       begin
         gridsize:=self.gridsize;
         readln(f,topx,topy,newrotate,newflip);
         offset.x:=splitpoint+topx*gridsize;
         offset.y:=topy*gridsize;
         readln(f,pointcount);
         nbrpoints:=0;
         for j:= 1 to pointcount do
         begin
           inc(nbrpoints);
           readln(f,newx,newy);
           with points[nbrpoints] do
           begin
            x:=newx;
            y:=newy;
           end;
         end;
         center.x:=0;
         center.y:=0;
         piececolor:=clwhite;
         piecenbr:=i+1;
         movable:=true;
         newrotate:=newrotate mod 8;  {piece definitions normally do not include rotate
                             or flip, but they can}
         //stop:=(8-newrotate);
         {for j:=1 to stop do }rotate45(8-newrotate);
         if newflip>0 then flip;
         makedrawpoints;
       end;
     end;
     closefile(f);
     invalidate;
     setlength(homepiece,length(piece));
     for i:= low(homepiece) to high(homepiece) do
     begin
       homepiece[i]:=TPiece.create;
       homepiece[i].assign(piece[i]);
     end;
   end
   else result:=false;
 end;

{******************* tTangram.LoadFigSet ***************}
procedure tTangram.loadfigset(fname:string);
{Load a figure definition file}
var
  ff:textfile;
  i,j:integer;
  newx,newy:integer;
  {version:integer; }
  count,newcolor,rotate,flip:integer;
  p:string;
begin
   if fileexists(fname) then
   begin
     assignfile(ff,fname);
     reset(ff);
     readln(ff {,version});
     readln(ff,piecesfilename);
     p:=piecesfilename;
     piecesfilename:=extractfilepath(fname)+p;
     {if pieces file not found in .tan directory, try program's directory}
     if not fileexists(piecesfilename) then  piecesfilename:=extractfilepath(application.exename)+p;
     if fileexists(piecesfilename)
     then
     if loadpieces(piecesfilename) then
     begin
       for i:= low(figures) to high(figures) do
       begin
         setlength(figures[i].fig,0);
         figures[i].free;
       end;
       setlength(figures,0);
       readln(ff,nbrfigures);
       setlength(figures,nbrfigures);
       for i:= 0 to nbrfigures-1 do
       begin
         figures[i]:=TFigpieces.create;
         readln(ff);
         setlength(figures[i].fig,nbrpieces);
         for j:= 0 to nbrpieces-1 do
         with figures[i] do
         begin
           readln(ff,count,newcolor,newx,newy,rotate,flip);
           //fig[j].pcolor:=colors[newcolor];
           fig[j].pcolor:=frmSettings.ColorBox2.Selected; //колір фігури
           if count>0 then
           begin
             with fig[j] do
             begin
               exists:=true;
               x:=newx;
               y:=newy;
               r:=rotate;
               f:=flip;
               piecenbr:=j+1;
             end;
           end;
         end;
       end;
     end
     else showmessage('Завантаження файлу '+piecesfilename+' невдале')
     else showmessage('Файл частин '+piecesfilename+' не знайдено');
     closefile(ff);
     invalidate;
   end;
 end;


 {******************** tTangram.AddPiece **************}
 procedure TTangram.addpiece(p:TPiece);
 begin
   setlength(piece,length(piece)+1);
   piece[high(piece)]:=p;
   inc(nbrpieces);
 end;

 {********************** tTangram.restart ******************}
 procedure tTangram.restart;
 {reset pieces to home position}
 var
   i:integer;
 begin
   for i:= low(homepiece) to high(homepiece)
   do piece[i].assign(homepiece[i]);
   PiecesInPlace:=0;
   drawdragged:=true;
   invalidate;
 end;


{********************* tTangram.Showfigure ********************}
procedure tTangram.showfigure(fignbr:integer);
var
  i,n:integer;
  p:TPiece;
  fx,fy:single;
begin
  n:=high(figures);
  if n>0 then
  begin
    if (fignbr=0)  then fignbr:=n+1;
    if fignbr>n+1 then curfig:=fignbr mod (high(figures)+1)
    else curfig:=fignbr;
  end
  else curfig:=1;  
  restart;
  {free old solution pieces}
  for i:=0 to high(solutionpieces) do solutionpieces[i].free;
  setlength(solutionpieces,0);

  n:=0;

  for i:=low(piece) to high(piece) do
  begin
    with figures[curfig-1].fig[i] do
    begin
      fx:=x;
      fy:=y;
      homepiece[i].piececolor:=pcolor;
      if exists then {only create solution pieces for those actually used
                      in this figure }
      begin
        homepiece[i].visible:=true;
        p:=TPiece.create; {create a new solutionpiece}
        with p do
        begin
          inc(n);
          setlength(solutionpieces,n);
          solutionpieces[n-1]:=P;
          assign(piece[i]);
          moveto(realpoint(fx-round(offset.x /gridsize),fy-round(offset.y /gridsize)));
          r:=r mod 8;  {Overmars files assume counterclockwise rotation and may}
          {stop:=(8-r);)  {be large or negative numbers, this changes value
                        to what we need}

          {for j:=1 to stop do }p.rotate45(8-r);
          if f>0 then p.flip;
          piececolor:=clwhite;
          piecenbr:=i+1;
          movable:=false;
          makedrawpoints;
        end;
      end
      else homepiece[i].visible:=false;
      {make an array of outside border points (any edge not shared)}

    end;
  end;
  restart;

  invalidate;
end;


var
  c1,c2:TColor; {moved here for debugging so optimization will not remove them }
  m,xincr,yincr,xchk1,xchk2,ychk1,ychk2:integer;
  x,y:integer;

{************* PieceInSolution ************}
function tTangram.pieceInSolution:boolean;
{to be valid drop location, try this:
  1. corners of piece all fall in solution pieces
  2. no edges intersect piece.
  3. no piece shares more than one side with another piece
  4. Added Sept 2003 - Piece must not be entirely within, or entirely surround another piece.
  5.Added November 2004, interior of piece must be iunterior to a pattern piece
 }
var
  i,j,k,r:integer;
  OK, OK2:boolean;
  L1,L2:TLine;
  sharedbordercount:array of integer;
  InOrOnCount:integer;
  onborder,colinear:boolean;
  count:integer;
  line1,line2:TLine;
  p1,p2, origp2:TPoint;

  endx,endy:integer;

  procedure swap(var p1,p2:TPoint);
  var t:TPoint;
  begin
    t:=p1;
    p1:=p2;
    p2:=t;
  end;

begin
  OK:=true;


  {1a. TRACE EDGES OF PIECE BEING DRAGGED - IF SAME COLOR ON BOTH SIDE AND COLOR
       IS NOT WHITE, DROP IS INVALID}

  with piece[dragnbr] do
  begin
    p1:=drawpoints[nbrpoints];
    for j:= 1 to nbrpoints do
    begin
      p2:=drawpoints[j];
      origp2:=p2;
      //form1.memo1.lines.add(format('Check (%d.%d) to (%d,%d)',[p1.x,p1.y,p2.x,p2.y]));
      {get smaller x then y as first point}
      if (p1.x>p2.x) or ((p1.x=p2.x) and (p1.y>p2.y)) then swap(p1,p2);
      endx:=p2.x;
      endy:=p2.y;

      {get slope}
      if p1.x=p2.x then m:=100
      else m:=(p2.y-p1.y) div (p2.x-p1.x);
      case m of
      0:
        begin
          xincr:=1; yincr:=0;
          xchk1:=0; xchk2:=0;
          ychk1:=1; ychk2:=-1;
        end;
      1:
        begin
          xincr:=1; yincr:=1;
          xchk1:=-1; ychk1:=-1;
          xchk2:=1; ychk2:=1;
        end;
      -1:
        begin
          xincr:=1; yincr:=-1;
          xchk1:=1; ychk1:=1;
          xchk2:=-1; ychk2:=-1;
        end;
        100:
        begin
          xincr:=0; yincr:=1;
          xchk1:=-1; ychk1:=0;
          xchk2:=1; ychk2:=0;
        end;
      end;
      x:=p1.x+xincr; {start one pixel into the line}
      y:=p1.y+yincr;
      count:=0;

      drawdragged:=false;
      repaint;    {repaint without the dragged piece so we can check its edges
                   for validity}

      repeat
        {check colors}
        inc(x,xincr);
        inc(y,yincr);
        c1:=canvas.pixels[x+xchk1,y+ychk1];
        c2:=canvas.pixels[x+xchk2,y+ychk2];
        if (c1=color) {and (c1>1) and (c2>1)} and (c1=c2) then
        begin
          ok:=false;
          break;
        end;
        inc(count);
      until ((x+2*xincr=endx) and (y+2*yincr=endy)) or (count>1000) ;
      if not ok then break;
      p1:=origp2;  {must use original value for next 1st point
                    in ends were were swapped}
    end;
  end;
  drawdragged:=true;
  repaint; {redraw with the current piece showing}

  {1b. corners of piece all fall in some solution space}
  if OK then
  with piece[dragnbr] do
  begin
    for j:= 1 to nbrpoints do
    begin
      OK2:=false;
      for i:= 0 to high(solutionpieces) do
              begin
                r:= solutionpieces[i].pointinpoly(drawpoints[j]);
        if (r=ppinside) or (r=ppedge) or (r=ppvertex) then
        begin
          OK2:=true;
          break;
        end;
      end;
      if not OK2 then
      begin
        OK:=false;
        break;
      end;
    end;
  end;

  {2.  no edge intersects another space (touching OK)  and
   3. if any 2 share more than one border, one is interior to the other}

   {we'll loop around the points of each piece, forming edges to test for
    intersections}
  if OK then
  begin
    setlength(sharedbordercount,length(piece));
    {keep track of shared borders with each piece}
    for i:= 0 to high(sharedbordercount) do sharedbordercount[i]:=0;
    for i:= 0 to high(piece) do
    if (i<>dragnbr) and (piece[i].drawcenter.x<splitpoint) then
    with piece[dragnbr] do
    begin
      L1.p1:=drawpoints[nbrpoints];
      InOrOnCount:=0;
      for j:= 1 to nbrpoints do
      begin
        L1.p2:=drawpoints[j];
        with piece[i] do
        begin
          L2.p1:=drawpoints[nbrpoints];
          for k:= 1 to nbrpoints do
          begin
            L2.p2:=drawpoints[k];
            if intersect(L1,L2,onborder,colinear)then
            begin
              if not onborder then
              begin
                OK:=false; {interior point found ==> invalid move}
                break;
              end
              else
              begin
                {borders might be colinear and not overlapped, ie just end-to-end
                 which is OK, if they overlap on two borders
                 then the polygons overlap
                 and the move is invalid}
                if colinear and overlapped(L1,L2) then
                begin
                  inc(sharedbordercount[i]);
                  if sharedbordercount[i]>1 then
                  begin
                    OK:=false;
                    break;
                  end;
                end;

              end;
            end;
            l2.p1:=drawpoints[k];
          end;
        end;
        r:=piece[i].pointinpoly(piece[dragnbr].drawpoints[j]);
        if (r=ppinside) or (r=ppedge) or (r=ppvertex)
        then inc(InorOnCount);
        If inOrOnCount>2 then
        begin
          OK:=false;
          break;
        end;
        if not Ok then break;
        l1.p1:=drawpoints[j];
      end;
    end;
  end;
  {4. Must not entirely surround or entirely enclose another piece}
  If OK then
  begin
    {Use pointInPoly -
    a. vertex of this piece against all other pieces
    b. a vertex of all othe pieces agaisnt this piece
    }

    for i:= 0 to high(piece) do
    if i<>dragnbr then
    begin
      {a}
      r:=piece[i].pointinpoly(piece[dragnbr].drawpoints[1]);
      if r=ppinside then
      begin
        OK:=false;
        break;
      end;
      {b}
      if OK then
      begin
        r:=piece[dragnbr].pointinpoly(piece[i].drawpoints[1]);
        if r=ppinside  then
        begin
          OK:=false;
          break;
        end;
      end;
    end;
  end;
  {5. Piece center is inside the solution space - added Nov, 2004}
  if ok then
  begin
    OK2:=false;
    for i:= 0 to high(solutionpieces) do
    begin
      r:= solutionpieces[i].pointinpoly(piece[dragnbr].drawcenter);
      if (r=ppinside) or (r=ppedge) or (r=ppvertex) then
      begin
        OK2:=true;
        break;
      end;
    end;
    if not OK2 then  OK:=false;
  end;
  result:=OK;
end;


{************** tTangram.showsolution ******************}
procedure tTangram.showsolution;
var
  i:integer;
  stop:integer;
  fx,fy:single;
begin
  restart;
  with figures[curfig-1] do
  begin
    for i := low(fig) to high(fig) do
    with fig[i], piece[i] do
    if exists then
    begin
       fx:=x;
       fy:=y;
       moveto(realpoint(fx-round(offset.x) div (gridsize),fy-round(offset.y) / (gridsize)));
       r:=r mod 8;
       rotate45(8-r);
       if f>0 then
       begin
         flip;
       end;
       makedrawpoints;
    end;
    piecesinplace:=high(fig)+1;
  end;  
  invalidate;
  (*    limit solution viewing
  application.processmessages;
  sleep(2500);  {show for 2 1/2 seconds}
  restart;
  invalidate;
  *)
end;


end.

