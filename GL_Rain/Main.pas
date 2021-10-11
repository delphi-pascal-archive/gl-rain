//*****************************************
// glRain - by Vlad PARCALABIOR (vlad@ifrance.com)  12.2000
// visit http://arrowsoft.ifrance.com
// based on ripple.c by Drew Olbrich, 1992
//*****************************************

unit Main;

interface

uses
  Windows, SysUtils, Forms, ExtCtrls,  Dialogs,
  OpenGL12, Geometry, Textures, Classes;

type
  TMouseButton = (mbLeft, mbRight, mbMiddle);
  TmForm = class(TForm)
    StartTimer: TTimer;
    FPStimer: TTimer;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure StartTimerTimer(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure AppMinimize(Sender: TObject);
    procedure AppRestore(Sender: TObject);
    procedure FPStimerTimer(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Timer1Timer(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

type
  tRIPPLE_VECTOR = record
    dx, dy: double;     // precomputed displacement vector table
    r: integer;		// distance from origin, in pixels
    end;

  tRIPPLE_VERTEX = record
    x: array[0..1] of double;  // initial vertex location
    u: array[0..1] of double;  // texture coordinate
    du,dv: double; // default texture coordinate
    end;

const FOV=60;
      GRID_SIZE_X= 32;
      GRID_SIZE_Y= 32;
      RIPPLE_LENGTH= 1024;
      RIPPLE_CYCLES= 10;
      RIPPLE_AMPLITUDE= 0.22;
      RIPPLE_STEP= 7;
      RIPPLE_COUNT= 12;
      tex1=1; tex2=2;
var
  mForm: TmForm;
  DC: HDC; HRC: HGLRC;
  vendor,renderer,dims,gcard: string;
  animate:boolean=false;
  frametime, starttime: cardinal;
  tick, tx:double;
  fps: word;
  ripple_vector: array[0..GRID_SIZE_X-1, 0..GRID_SIZE_Y-1] of tRIPPLE_VECTOR;
  amplitude: array[0..RIPPLE_LENGTH-1] of double;
  ripple_vertex: array[0..GRID_SIZE_X-1, 0..GRID_SIZE_Y-1] of tRIPPLE_VERTEX;
  cx, cy, t, max: array[0..RIPPLE_COUNT-1] of integer;
  ripple_max: integer;
  sizex: integer=500; sizey: integer= 500;
  texObj: array [0..1] of GLenum;

implementation
{$R *.DFM}

procedure precalc_ripple_vector;
var i, j: integer;
    x, y, l: double;
begin
for i:=0 to GRID_SIZE_X-1 do
 for j:=0 to GRID_SIZE_Y-1 do
  begin
  x:= i/(GRID_SIZE_X - 1);
  y:= j/(GRID_SIZE_Y - 1);

  l:= sqrt(x*x + y*y);
  if l = 0.0 then
   begin
   x:= 0.0;
   y:= 0.0;
   end
  else
   begin
   x:=x/l;
   y:=y/l;
   end;

  ripple_vector[i,j].dx:=x;
  ripple_vector[i,j].dy:=y;
  ripple_vector[i,j].r:=round(l*sizex*2);
  end;
end;

procedure precalc_ripple_amp;
var i: integer;
    t: double;
begin
for i:= 0 to RIPPLE_LENGTH-1 do
 begin
 t:= 1.0 - i/(RIPPLE_LENGTH - 1.0);
 if i = 0 then amplitude[i]:= 0.0
 else
  amplitude[i]:= (-cos(t*2.0*3.1428571*RIPPLE_CYCLES)*0.5 + 0.5)
                  *RIPPLE_AMPLITUDE*t*t*t*t*t*t*t*t;
 end;
end;


procedure ripple_init;
var i, j: integer;
begin
ripple_max:= round(sqrt(sizey*sizey+sizex*sizex));

for i:= 0 to RIPPLE_COUNT-1 do
 begin
 t[i]:= ripple_max + RIPPLE_LENGTH;
 cx[i]:= 0;
 cy[i]:= 0;
 max[i]:= 0;
 end;

for i:= 0 to GRID_SIZE_X - 1 do
 for j:= 0 to GRID_SIZE_Y - 1 do
  begin
  ripple_vertex[i,j].x[0]:= i/(GRID_SIZE_X - 1)* sizex;
  ripple_vertex[i,j].x[1]:= j/(GRID_SIZE_Y - 1)* sizey;
  ripple_vertex[i,j].du:= i/(GRID_SIZE_X - 1);
  ripple_vertex[i,j].dv:= j/(GRID_SIZE_Y - 1);
  end;
end;

procedure ripple_dynamics;
var
  i, j, k, x, y, mi, mj, r: integer;
  sx, sy, amp: double;
begin
for i:= 0 to RIPPLE_COUNT-1 do
 t[i]:=t[i] + round(tick);

for i:= 0 to GRID_SIZE_X-1 do
 for j:= 0 to GRID_SIZE_Y-1 do
  begin
  ripple_vertex[i,j].u[0]:= ripple_vertex[i,j].du;
  ripple_vertex[i,j].u[1]:= ripple_vertex[i,j].dv;

  for k:= 0 to RIPPLE_COUNT -1 do
   begin
   x:= i - cx[k];
   y:= j - cy[k];
   if x < 0 then
    begin
    x:= x* -1;
    sx:= -1.0;
    end
   else
    sx:= 1.0;
   if y < 0 then
    begin
    y:=y* -1;
    sy:= -1.0;
    end
   else
    sy:= 1.0;
   mi:= x;
   mj:= y;

   r:= t[k] - ripple_vector[mi,mj].r;

   if r < 0 then r:= 0;
   if r > RIPPLE_LENGTH - 1 then r:= RIPPLE_LENGTH - 1;

   amp:= 1.0 - 1.0*t[k]/RIPPLE_LENGTH;
   amp:=amp* amp;
   if amp < 0.0 then amp:= 0.0;

   ripple_vertex[i,j].u[0]:= ripple_vertex[i,j].u[0]+
	   ripple_vector[mi, mj].dx *sx*amplitude[r]*amp;
   ripple_vertex[i,j].u[1]:=ripple_vertex[i,j].u[1]+
	   ripple_vector[mi, mj].dy *sy*amplitude[r]*amp;
   end;
  end;
end;

function ripple_max_distance(gx, gy: integer):integer;
var  d, temp_d: double;
begin
d := sqrt(1.0*gx*gx + 1.0*gy*gy);
temp_d := sqrt(1.0*(gx - GRID_SIZE_X)*(gx - GRID_SIZE_X) + 1.0*gy*gy);
if temp_d > d then d := temp_d;

temp_d := sqrt(1.0*(gx - GRID_SIZE_X)*(gx - GRID_SIZE_X) + 1.0*(gy - GRID_SIZE_Y)*(gy - GRID_SIZE_Y));
if temp_d > d then d := temp_d;

temp_d := sqrt(1.0*gx*gx + 1.0*(gy - GRID_SIZE_Y)*(gy - GRID_SIZE_Y));
if temp_d > d then d := temp_d;

result:=round((d/GRID_SIZE_X)*sizex + RIPPLE_LENGTH/6);
end;

procedure ripple_drop(mx, my: integer);
var index: integer;
begin
index := 0;
while (index < RIPPLE_COUNT) and (t[index] < max[index]) do
     index:=index+1;

if index < RIPPLE_COUNT then
 begin
 cx[index] := round(mx/sizex*GRID_SIZE_X);
 if cx[index]>=GRID_SIZE_X then cx[index]:= GRID_SIZE_X-1;
 cy[index] := round(my/sizey*GRID_SIZE_Y);
 if cy[index]>=GRID_SIZE_Y then cy[index]:= GRID_SIZE_Y-1;
 t[index] := 4*RIPPLE_STEP;
 max[index] := ripple_max_distance(cx[index], cy[index]);
 end;
end;

procedure ResizeViewport(width,height:longint);
 var znear, zfar: GLdouble;
begin
znear := -200;
zfar  := 200;
glViewport(0, 0, width, height);
glMatrixMode(GL_PROJECTION);
glLoadIdentity();
glOrtho(0, width+1, 0, height , znear, zfar);
sizex:=width; sizey:=height;
glMatrixMode(GL_MODELVIEW);
precalc_ripple_vector;
ripple_init;
end;

Procedure SetupGL(width,height:longint);
var tex:ttexture;
begin
glClearColor(0.0, 0.0, 0.0, 0.0);
glFrontFace(GL_CW);
gldisable(GL_DEPTH_TEST);
glenable(GL_CULL_FACE);

ResizeViewport(width, height);

if not GL_ARB_multitexture then
 begin
 MessageDlg('Your driver does not support ARB_multitexture!', mtError, [mbOk], 0);
 Halt(1);
 end;

tex:=ttexture.Load(tex1,'sky.jpg');
glActiveTextureARB(GL_TEXTURE0_ARB);
glBindTexture(GL_TEXTURE_2D, tex.ID);
glEnable(GL_TEXTURE_2D);
glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_repeat);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_clamp);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_linear);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_Linear_MIPMAP_nearest);
gluBuild2DMipmaps(GL_TEXTURE_2D, 4, tex.width, tex.height,
                  GL_RGBA, GL_UNSIGNED_BYTE, tex.pixels);
gldisable(GL_BLEND);
tex.free;

tex:=ttexture.Load(tex2,'ogl.tga');
glActiveTextureARB(GL_TEXTURE1_ARB);
glBindTexture(GL_TEXTURE_2D, tex.ID);
glenable(GL_TEXTURE_2D);
glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_linear);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_Linear_MIPMAP_nearest);
gluBuild2DMipmaps(GL_TEXTURE_2D, 4, tex.width, tex.height,
                  GL_RGBA, GL_UNSIGNED_BYTE, tex.pixels);
glEnable(GL_BLEND);
tex.free;

glBlendFunc(gl_one, gl_one_minus_dst_alpha);

gluLookAt(0,0,200,0,0,0,0,1,0);
end;

procedure MainLoop;
var i,j: word;
begin
tx:=0;
repeat
 starttime:=gettickcount;
 ripple_dynamics;
// glClear(GL_COLOR_BUFFER_BIT);

 for j:= 0 to GRID_SIZE_Y - 2 do
  begin
  glBegin(GL_QUAD_STRIP);
  for i:= 0 to GRID_SIZE_X - 1 do
    begin
    glMultiTexCoord2fARB(GL_TEXTURE0_ARB, ripple_vertex[i,j].u[0]/3+tx, ripple_vertex[i,j].u[1]);
    glMultiTexCoord2fARB(GL_TEXTURE1_ARB, ripple_vertex[i,j].u[0], ripple_vertex[i,j].u[1]);
    glVertex2f(ripple_vertex[i,j].x[0], ripple_vertex[i,j].x[1]);

    glMultiTexCoord2fARB(GL_TEXTURE0_ARB, ripple_vertex[i,j + 1].u[0]/3+tx, ripple_vertex[i,j + 1].u[1]);
    glMultiTexCoord2fARB(GL_TEXTURE1_ARB, ripple_vertex[i,j + 1].u[0], ripple_vertex[i,j + 1].u[1]);
    glVertex2f(ripple_vertex[i,j + 1].x[0], ripple_vertex[i,j + 1].x[1]);
    end;
  glEnd;
 end;


 glFinish;
 SwapBuffers(DC);
 frametime:=gettickcount-starttime;
 tick:=frametime/1.3;
 tx:=tx+frametime/24000;
 inc(fps);
 Application.ProcessMessages;
until not animate;
end;

procedure StartAnimation;
begin
animate:=true;
mForm.FPStimer.Enabled:=true;
MainLoop;
end;

procedure TmForm.FormCreate(Sender: TObject);
begin
if not InitOpenGL then halt(1);
DC := GetDC(handle);
HRC:=CreateRenderingContext(DC,[opDoubleBuffered],32,0,0,0,0);
ActivateRenderingContext(DC,HRC);
SetupGL(ClientWidth, ClientHeight);

dims:=inttostr(clientwidth)+'/'+inttostr(clientheight);
renderer:=StrPas(PChar(glGetString(GL_renderer)));
vendor:=StrPas(PChar(glGetString(GL_vendor)));
gcard:='GL Rain ('+dims+' fps: ';
caption:=gcard+')';

randomize;
precalc_ripple_vector;
precalc_ripple_amp;

Application.OnMinimize:= AppMinimize;
Application.OnRestore:= AppRestore;
StartTimer.Enabled:=true;
end;

procedure TmForm.AppMinimize(Sender: TObject);
begin
 Animate:=false;
 mForm.FPStimer.Enabled:=false;
end;

procedure TmForm.AppRestore(Sender: TObject);
begin
 StartAnimation;
end;

procedure TmForm.FormResize(Sender: TObject);
begin
resizeviewport(ClientWidth, ClientHeight);
dims:=inttostr(clientwidth)+'/'+inttostr(clientheight);
gcard:='GL Rain ('+dims+' fps: ';
end;

procedure TmForm.FormDestroy(Sender: TObject);
begin
DestroyRenderingContext(hrc);
CloseOpenGL;
end;

procedure TmForm.StartTimerTimer(Sender: TObject);
begin
StartTimer.Enabled:=false;
StartAnimation;
end;

procedure TmForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
animate:=false;
mForm.FPStimer.Enabled:=false;
Action:=caFree;
end;

procedure TmForm.FPStimerTimer(Sender: TObject);
begin
caption:=gcard+inttostr(fps)+')';
fps:=0;
end;

procedure TmForm.FormKeyPress(Sender: TObject; var Key: Char);
begin
if key=#27 then begin animate:=false;close;end;
if key=#32 then begin timer1.Enabled:=not timer1.Enabled; beep;end; 
end;

procedure TmForm.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
ripple_drop(x,clientheight-y);
end;

procedure TmForm.Timer1Timer(Sender: TObject);
begin
ripple_drop(random(sizex), random(sizey));
end;

end.
