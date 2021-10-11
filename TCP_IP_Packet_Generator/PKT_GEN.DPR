program Pkt_Gen;

uses
  Forms,
  UPkt_Gen in 'UPkt_Gen.pas' {Form1},
  tcpiphlp in 'tcpiphlp.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
