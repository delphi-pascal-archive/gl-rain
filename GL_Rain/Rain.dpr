program Rain;

uses
  Forms,
  Main in 'Main.pas' {mForm},
  Geometry in 'Geometry.pas',
  Textures in 'Textures.pas',
  OpenGL12 in 'OpenGL12.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'OpenGL Rain';
  Application.CreateForm(TmForm, mForm);
  Application.Run;
end.
