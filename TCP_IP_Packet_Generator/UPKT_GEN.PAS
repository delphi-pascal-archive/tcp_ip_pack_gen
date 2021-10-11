unit UPkt_Gen;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, UPkt_Snd, TcpIpHlp;

type
  TForm1 = class(TForm)
    TopPanel: TPanel;
    MainPanel: TPanel;
    GroupBox2: TGroupBox;
    DstIpEdit: TEdit;
    SrcIpEdit: TEdit;
    TtlEdit: TEdit;
    RandomSrcIP: TCheckBox;
    RandomDstIP: TCheckBox;
    SrcPortEdit: TEdit;
    DstPortEdit: TEdit;
    SequenceEdit: TEdit;
    FlagsGroupBox: TGroupBox;
    FinFlag: TCheckBox;
    SynFlag: TCheckBox;
    RstFlag: TCheckBox;
    PshFlag: TCheckBox;
    AckFlag: TCheckBox;
    UrgFlag: TCheckBox;
    RandomSrcPort: TCheckBox;
    RandomDstPort: TCheckBox;
    UseRandomSeq: TCheckBox;
    DataMemo: TMemo;
    NumPacketsEdit: TEdit;
    DelayEdit: TEdit;
    ResultMemo: TMemo;
    GoButton: TButton;
    TabControl: TTabControl;
    SrcIPLabel: TLabel;
    DstIPLabel: TLabel;
    TTLLabel: TLabel;
    SrcPortLabel: TLabel;
    DstPortLabel: TLabel;
    SeqNoLabel: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    procedure RandomSrcIPClick(Sender: TObject);
    procedure RandomDstIPClick(Sender: TObject);
    procedure RandomSrcPortClick(Sender: TObject);
    procedure RandomDstPortClick(Sender: TObject);
    procedure UseRandomSeqClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure GoButtonClick(Sender: TObject);
    procedure TabControlChange(Sender: TObject);
  private
    { Private declarations }
    FRandomSrcTCP, { save checkmarks for TCP,UDP and Ping }
    FRandomDstTCP,
    FRandomSrcUDP,
    FRandomDstUDP,
    FRandomIdPing,
    FRandomSqPing: Boolean;
    FProtocolType: TProtocolType; { protocol tab }

    function  AcceptUserInput(Sender: TSenderIP; x: TProtocolType): Boolean;
    function  AcceptIPSettings(ip: TSenderIP): Boolean;
    function  AcceptTcpSettings(tcp: TSenderTCP): Boolean;
    function  AcceptUdpSettings(udp: TSenderUDP): Boolean;
    function  AcceptPingSettings(ping: TSenderICMP): Boolean;
    procedure PrintLine(s: String);

  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

var WarnedAboutW2k: Boolean = FALSE;

procedure WarnAboutW2k;
begin
  if NOT WarnedAboutW2k then
  begin
    WarnedAboutW2k := TRUE;
    if NOT Win2KDetected then
      ShowMessage('Warning: This application requires Windows 2000/XP, '
                 +'which weren''t detected on this computer. '
                 +'Therefore you are likely to get socket errors because '
                 +'of the insufficient MS Winsock implementation.');
  end
end;

procedure TForm1.PrintLine(s: String);
// Output a line of text to the results memo
begin
  Form1.ResultMemo.Lines.Add(s)
end;

function TForm1.AcceptIPSettings(ip: TSenderIP): Boolean;
// Verify and accept IP settings typed by the user
begin
  Result := FALSE;

  ip.UseRandomSrcIP   := RandomSrcIP.Checked;
  ip.UseRandomDstIP   := RandomDstIP.Checked;
  ip.Data             := DataMemo.Text;

  ip.DelayBetweenPackets := StrToIntDef(DelayEdit.Text, 1000);
  DelayEdit.Text := IntToStr(ip.DelayBetweenPackets);

  ip.NumPackets := StrToIntDef(NumPacketsEdit.Text, 1);
  NumPacketsEdit.Text := IntToStr(ip.NumPackets);

  ip.TimeToLive := StrToIntDef(TtlEdit.Text, 1);
  TtlEdit.Text := IntToStr(ip.TimeToLive);

  if NOT ip.UseRandomSrcIP then
  begin
    try
      ip.SourceHost := SrcIpEdit.Text;
    except
      ShowMessage('Unknown Source host: '+ SrcIpEdit.Text);
      Exit;
    end;
  end;

  if NOT ip.UseRandomDstIP then
  begin
    try
      ip.DestinationHost := DstIpEdit.Text;
    except
      ShowMessage('Unknown Destination host: '+ DstIpEdit.Text);
      Exit;
    end;
  end;

  Result := TRUE;
end;

function TForm1.AcceptTcpSettings(tcp: TSenderTCP): Boolean;
// Verify and accept TCP settings typed by the user
VAR x: DWORD;
begin
  Result := AcceptIPSettings(tcp);
  if Result then
  begin
    tcp.UseRandomSrcPort := RandomSrcPort.Checked;
    tcp.UseRandomDstPort := RandomDstPort.Checked;

    tcp.FinFlag := FinFlag.Checked;
    tcp.SynFlag := SynFlag.Checked;
    tcp.RstFlag := RstFlag.Checked;
    tcp.PshFlag := PshFlag.Checked;
    tcp.AckFlag := AckFlag.Checked;
    tcp.UrgFlag := UrgFlag.Checked;

    if NOT RandomSrcPort.Checked then
    begin
      x := StrToIntDef(DstPortEdit.Text, 80);
      if x < 1 then
      begin
        x := 80;
        SrcPortEdit.Text := '80';
      end;
      tcp.SourcePort := x;
    end;


    if NOT RandomDstPort.Checked then
    begin
      x := StrToIntDef(DstPortEdit.Text, 80);
      if x < 1 then
      begin
        x := 80;
        DstPortEdit.Text := '80';
      end;
      tcp.DestinationPort := x;
    end;

    x := DWORD(StrToIntDef(SequenceEdit.Text, 12345678));
    if (x < 1) OR UseRandomSeq.Checked then
      x := DWORD(Random(MaxInt-1)+1);
    SequenceEdit.Text := IntToStr(x);
    tcp.SequenceNumber := x;
  end;
end;

function TForm1.AcceptUdpSettings(udp: TSenderUDP): Boolean;
// Verify UDP settings typed by the user
begin
  Result := AcceptIPSettings(udp);
  if Result then
  begin
    udp.UseRandomSrcPort := RandomSrcPort.Checked;
    udp.UseRandomDstPort := RandomDstPort.Checked;

    if NOT RandomSrcPort.Checked then
      udp.SourcePort := StrToIntDef(DstPortEdit.Text, 0);

    if NOT RandomDstPort.Checked then
      udp.DestinationPort := StrToIntDef(DstPortEdit.Text, 0);
  end;
end;

function TForm1.AcceptPingSettings(ping: TSenderICMP): Boolean;
// Verify ICMP/Ping settings typed by the user
begin
  Result := AcceptIPSettings(ping);
  if Result then
  begin
    // This code may seem slightly confusing,
    // since there are no ports in the ICMP header.
    // Try to ignore the variable names here;
    // we simply re-use FSrcPort as Ping ID field,
    // and FDstPort as the Ping Sequence number.
    //
    ping.UseRandomPingID := RandomSrcPort.Checked;
    ping.UseRandomPingSequence := RandomDstPort.Checked;

    if NOT RandomSrcPort.Checked then
      ping.PingID := StrToIntDef(DstPortEdit.Text, $1234);
    if NOT RandomDstPort.Checked then
      ping.PingSequence := StrToIntDef(DstPortEdit.Text, $4321);
  end;
end;

function  TForm1.AcceptUserInput(Sender: TSenderIP; x: TProtocolType): Boolean;
begin
  ResultMemo.Clear;  { clear the results field }

  Sender.OnPrintLine := PrintLine; { progress feedback }

  // Verify Protocol settings typed by the user
  // depending on the selected protocol type
  //
  case x of
    ptUDP:  Result := AcceptUdpSettings(TSenderUDP(Sender));
    ptICMP: Result := AcceptPingSettings(TSenderICMP(Sender));
    else    Result := AcceptTcpSettings(TSenderTCP(Sender));
  end
end;

procedure TForm1.RandomSrcIPClick(Sender: TObject);
begin
  SrcIpEdit.Enabled := NOT RandomSrcIP.Checked
end;

procedure TForm1.RandomDstIPClick(Sender: TObject);
begin
  DstIpEdit.Enabled := NOT RandomDstIP.Checked
end;

procedure TForm1.RandomSrcPortClick(Sender: TObject);
begin
  SrcPortEdit.Enabled := NOT RandomSrcPort.Checked;
  case FProtocolType of
    ptUDP:  FRandomSrcUDP := RandomSrcPort.Checked;
    ptICMP: FRandomIdPing := RandomSrcPort.Checked;
    else    FRandomSrcTCP := RandomSrcPort.Checked;
  end;
end;

procedure TForm1.RandomDstPortClick(Sender: TObject);
begin
  DstPortEdit.Enabled := NOT RandomDstPort.Checked;
  case FProtocolType of
    ptUDP:  FRandomDstUDP := RandomDstPort.Checked;
    ptICMP: FRandomSqPing := RandomDstPort.Checked;
    else    FRandomDstTCP := RandomDstPort.Checked;
  end;
end;

procedure TForm1.UseRandomSeqClick(Sender: TObject);
begin
  SequenceEdit.Enabled := NOT UseRandomSeq.Checked
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  FRandomSrcTCP := TRUE;
  UseRandomSeq.Checked := TRUE;
  TabControl.OnChange(Sender); { init tab control w/TCP settings }
end;

procedure TForm1.GoButtonClick(Sender: TObject);
VAR x: TSenderIP;
begin
  // This is the main routine.

  // Disable user input
  //
  TopPanel.Enabled := FALSE;
  MainPanel.Enabled := FALSE;
  Application.ProcessMessages;

  try

    WarnAboutW2k;      // We want Win2K

    // Create a specific sender object (TCP, UDP
    // or ICMP/Ping) depending on the currently
    // selected (active) protocol Tab.
    //
    case FProtocolType of
      ptUDP:  x := TSenderUDP.Create;
      ptICMP: x := TSenderICMP.Create;
      else begin
        FProtocolType := ptTCP;
        x := TSenderTCP.Create;
      end;
    end;
    x.OnExecute := AcceptUserInput;

    try

      // This will verify and accept the user input,
      // and send one or more packets to the network.
      //
      x.Execute;
    finally
      x.Free;
    end
  finally
    MainPanel.Enabled := TRUE;
    TopPanel.Enabled := TRUE;
  end
end;

procedure TForm1.TabControlChange(Sender: TObject);
begin
  // When the protocol Tab changes we update
  // the caption of the Go button, modify
  // labels, and hide or show relevant fields
  //
  case TabControl.TabIndex of
    1:   { UDP }
      begin
        FProtocolType := ptUDP;
        GoButton.Caption := 'Generate UDP Packets';
        SrcPortLabel.Caption  := 'Source Port: ';
        DstPortLabel.Caption  := 'Destination Port: ';
        RandomSrcPort.Checked := FRandomSrcUDP; { restore checkmarks }
        RandomDstPort.Checked := FRandomDstUDP;
        SeqNoLabel.Visible    := FALSE;
        SequenceEdit.Visible  := FALSE;
        UseRandomSeq.Visible  := FALSE;
        FlagsGroupBox.Visible := FALSE;
      end;
    2:   { ICMP/Ping }
      begin
        FProtocolType := ptICMP;
        GoButton.Caption := 'Generate Ping Packets';
        SrcPortLabel.Caption  := 'ID: ';
        DstPortLabel.Caption  := 'Sequence: ';
        RandomSrcPort.Checked := FRandomIdPing;
        RandomDstPort.Checked := FRandomSqPing;
        SeqNoLabel.Visible    := FALSE;
        SequenceEdit.Visible  := FALSE;
        UseRandomSeq.Visible  := FALSE;
        FlagsGroupBox.Visible := FALSE;
      end;
    else { TCP }
      begin
        FProtocolType := ptTCP;
        GoButton.Caption := 'Generate TCP Packets';
        SrcPortLabel.Caption  := 'Source Port: ';
        DstPortLabel.Caption  := 'Destination Port: ';
        RandomSrcPort.Checked := FRandomSrcTCP;
        RandomDstPort.Checked := FRandomDstTCP;
        SeqNoLabel.Visible    := TRUE;
        SequenceEdit.Visible  := TRUE;
        UseRandomSeq.Visible  := TRUE;
        FlagsGroupBox.Visible := TRUE;
      end;
  end
end;

end.
