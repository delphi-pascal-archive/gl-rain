{Textures v2.0 22.12.2000 by ArrowSoft-VMP}
//
//All textures are stored as RGBA8 as it is more efficient as RGB8!!
//TGA textures should not be Read-Only!!

unit Textures;

interface
type
     TColorRGB = packed record
               r, g, b	: BYTE;
               end;
     PColorRGB = ^TColorRGB;

     TRGBList = packed array[0..0] of TColorRGB;
     PRGBList = ^TRGBList;

     TColorRGBA = packed record
               r, g, b, a : BYTE;
               end;
     PColorRGBA = ^TColorRGBA;

     TRGBAList = packed array[0..0] of TColorRGBA;
     PRGBAList = ^TRGBAList;

     TTexture=class(tobject)
      ID, width, height:integer;
      pixels: pRGBAlist;
      constructor Load(tID:integer;filename:string);
      destructor destroy; override;
     end;

     TVoidTexture=class(tobject)
      ID, width, height:integer;
      pixels: pRGBAlist;
      constructor create(tid, twidth, theight:integer);
      destructor destroy; override;
     end;

implementation
uses dialogs, sysutils, graphics, jpeg;

constructor tTexture.Load(tID:integer; filename:string);
var f:file;
    atype: array [0..3] of Byte;
    info: array [0..6] of Byte;
    actread:integer;
    fext:string;
    bmp:tbitmap; jpg:tjpegimage;
    i,j:integer;
    pixline: pRGBlist;
    pixrgba: pRGBAlist;
    r,g,b:byte;

begin
inherited create;
if not fileexists(filename) then begin messagedlg(filename+' not found',mterror,[mbabort],0); halt(1);end;
fExt:=uppercase(ExtractFileExt(filename));
ID:=tID;
if fext='.BMP' then
 begin
 bmp:=TBitmap.Create;
 bmp.HandleType:=bmDIB;
 bmp.PixelFormat:=pf24bit;
 bmp.LoadFromFile(filename);
 Width:=bmp.Width;
 Height:=bmp.Height;
 getmem(pixels,width*height*4);
 for i:=0 to height-1 do
  begin
  pixline:=bmp.ScanLine[height-1-i];
  for j:=0 to width-1 do
   begin
   r:=pixline[j].b;
   g:=pixline[j].g;
   b:=pixline[j].r;
   pixels[i*width+j].r:=r;
   pixels[i*width+j].g:=g;
   pixels[i*width+j].b:=b;
   pixels[i*width+j].a:=255;
   end;
  end;
 bmp.Free;
 end
else
 if fext='.JPG' then
  begin
  jpg:=tjpegimage.Create;
  jpg.LoadFromFile(filename);
  bmp:=TBitmap.Create;
  bmp.HandleType:=bmDIB;
  bmp.PixelFormat:=pf24bit;
  Width:=jpg.Width;
  Height:=jpg.Height;
  bmp.Width:=Width;
  bmp.Height:=Height;
  bmp.Assign(jpg);
  getmem(pixels,width*height*4);
  for i:=0 to height-1 do
   begin
   pixline:=bmp.ScanLine[height-1-i];
   for j:=0 to width-1 do
    begin
    r:=pixline[j].b;
    g:=pixline[j].g;
    b:=pixline[j].r;
    pixels[i*width+j].r:=r;
    pixels[i*width+j].g:=g;
    pixels[i*width+j].b:=b;
    pixels[i*width+j].a:=255;
    end;
   end;
  bmp.Free;
  jpg.Free;
  end
 else
  if fext='.TGA' then
   begin
   assign(f,filename);
   {$i-}
   Reset(f, 1);
   BlockRead(f, atype, 4, actread);
   if (ioresult<>0) or (actread<>4) then begin messagedlg(filename+' - unrecognized format',mterror,[mbabort],0); halt(1);end;
   Seek(f, 12);
   BlockRead(f, info, 7, actread);
   if (ioresult<>0) or (actread<>7) then begin messagedlg(filename+' - unrecognized format',mterror,[mbabort],0); halt(1);end;
   {$i+}
   if (atype[1] <> 0) or (atype[2] <> 2) then begin messagedlg(filename+' - unrecognized format',mterror,[mbabort],0); halt(1);end;
   if (info[4] <> 32) and (info[4] <> 24) then begin messagedlg(filename+' - unrecognized format',mterror,[mbabort],0); halt(1);end;

   Width:=info[0] + info[1] * 256;
   Height:=info[2] + info[3] * 256;

   if info[4]= 24 then
    begin
    getmem(pixline, width*height*3);  //RGB list
    blockread(f,pixline^,width*height*3,actread);
    if actread <> width*height*3 then
     begin
     freemem(pixline);
     messagedlg(filename+' - read error',mterror,[mbabort],0); halt(1);
     end;
    getmem(pixels, width*height*4);
    for i:=0 to width*height-1 do
     begin
     pixels[i].r:=pixline[i].g;
     pixels[i].g:=pixline[i].r;
     pixels[i].b:=pixline[i].b;
     pixels[i].a:=255;
     end;
    freemem(pixline);
    end
   else  //bpp=32
    begin
    getmem(pixrgba, width*height*4);
    blockread(f,pixrgba^,width*height*4,actread);
    if actread <> width*height*4 then
     begin
     freemem(pixrgba);
     messagedlg(filename+' - read error',mterror,[mbabort],0); halt(1);
     end;
    getmem(pixels, width*height*4);
    for i:=0 to width*height-1 do
     begin
     pixels[i].r:=pixrgba[i].g;
     pixels[i].g:=pixrgba[i].r;
     pixels[i].b:=pixrgba[i].a;
     pixels[i].a:=pixrgba[i].b;
     end;
    freemem(pixrgba);
    end;
   closefile(f);
   end;

end;

destructor TTexture.destroy;
begin
freemem(pixels);
inherited destroy;
end;

constructor tvoidtexture.create(tid, twidth, theight:integer);
begin
inherited create;
id:=tid;
width:=twidth; height:=theight;
getmem(pixels,width*height*4);
end;

destructor tvoidtexture.destroy;
begin
freemem(pixels);
inherited destroy;
end;

end.
