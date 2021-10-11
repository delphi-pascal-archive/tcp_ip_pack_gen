unit UPkt_Snd;

interface

uses
  Windows, SysUtils, Forms, Winsock, TcpIpHlp;

type
  TSenderIP = class;
  TProtocolType = (ptTCP, ptUDP, ptICMP);
  TOnExecuteEvent = function (Sender: TSenderIP; x: TProtocolType): Boolean of Object;
  TOnPrintLineEvent = procedure (s: String) of Object;

  TSenderIP = class(TObject)  // IP Packet Sender Class
  private
    FProtocol: Word;
    FSocket: TSocket;

    FNumPackets: Word;
    FMaxPackets: Word;
    FSrcIP, FDstIP: DWORD;
    FSourceHost: String;
    FDestinationHost: String;
    FDelay: DWORD;

    FTimeToLive: Byte;

    FRandomSrcIP,
    FRandomDstIP: Boolean;

    FData: String;
    FDataLen: Integer;

    FOnExecute: TOnExecuteEvent;
    FOnPrintLine: TOnPrintLineEvent;

    function  GetLength: Word; virtual; abstract;
    function  SendDatagram(ih: THdrIP; data: PChar; dlen: Integer): Integer; virtual; abstract;
    procedure UpdateSequence; virtual;

    procedure PrintLine(s: String);
    procedure ThrowException(msg: String; eCode: Integer);

    procedure SetNumPackets(value: Word);
    procedure SetSrcIP(value: String);
    procedure SetDstIP(value: String);
    procedure SetDelay(value: DWORD);
    procedure SetData(value: String);

    procedure SendPackets;
    procedure SendOnePacket;
    function  SendToRemote(addr, port: Integer;
                           buffer: PChar; len: Integer): Integer;

   {$ifdef DUMP_MODE}
    procedure Dump(data: PByte; len: Integer);
   {$endif}

  protected
    FRandomSrcPort,
    FRandomDstPort: Boolean;
    FSrcPort, FDstPort: Word;
    FIpBuffer: Array [1..$FFFF] of Char; // IP packet cannot be bigger than 64K

  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure Execute;

    property  NumPackets: Word read FNumPackets write SetNumPackets;
    property  SourceHost: String read FSourceHost write SetSrcIP;
    property  DestinationHost: String read FDestinationHost write SetDstIP;
    property  DelayBetweenPackets: DWORD read FDelay write SetDelay;
    property  TimeToLive: Byte read FTimeToLive write FTimeToLive;

    property  UseRandomSrcIP: Boolean read FRandomSrcIP write FRandomSrcIP;
    property  UseRandomDstIP: Boolean read FRandomDstIP write FRandomDstIP;

    property  Data: String read FData write SetData;

    property  OnExecute: TOnExecuteEvent read FOnExecute write FOnExecute;
    property  OnPrintLine: TOnPrintLineEvent read FOnPrintLine write FOnPrintLine;
  end;

  TSenderTCP = class(TSenderIP)  // TCP Packet Sender
  private
    FSequence: DWORD;
    FFinFlag, { TCP flags }
    FSynFlag,
    FRstFlag,
    FPshFlag,
    FAckFlag,
    FUrgFlag: Boolean;

    function  SendDatagram(ih: THdrIP; data: PChar; dlen: Integer): Integer; override;
    function  GetLength: Word; override;
    procedure UpdateSequence; override;
  public
    constructor Create; override;

    property  SequenceNumber: DWORD read FSequence write FSequence;
    property  FinFlag: Boolean read FFinFlag write FFinFlag;
    property  SynFlag: Boolean read FSynFlag write FSynFlag;
    property  RstFlag: Boolean read FRstFlag write FRstFlag;
    property  PshFlag: Boolean read FPshFlag write FPshFlag;
    property  AckFlag: Boolean read FAckFlag write FAckFlag;
    property  UrgFlag: Boolean read FUrgFlag write FUrgFlag;

    property  SourcePort: Word read FSrcPort write FSrcPort;
    property  DestinationPort: Word read FDstPort write FDstPort;
    property  UseRandomSrcPort: Boolean read FRandomSrcPort write FRandomSrcPort;
    property  UseRandomDstPort: Boolean read FRandomDstPort write FRandomDstPort;
  end;

  TSenderUDP = class(TSenderIP)  // UDP Packet Sender
  private
    function  SendDatagram(ih: THdrIP; data: PChar; dlen: Integer): Integer; override;
    function  GetLength: Word; override;
  public
    constructor Create; override;

    property  SourcePort: Word read FSrcPort write FSrcPort;
    property  DestinationPort: Word read FDstPort write FDstPort;
    property  UseRandomSrcPort: Boolean read FRandomSrcPort write FRandomSrcPort;
    property  UseRandomDstPort: Boolean read FRandomDstPort write FRandomDstPort;
  end;

  TSenderICMP = class(TSenderIP)  // Ping Packet Sender
  private
    function  SendDatagram(ih: THdrIP; data: PChar; dlen: Integer): Integer; override;
    function  GetLength: Word; override;
  public
    constructor Create; override;

    property  PingID: Word read FSrcPort write FSrcPort;
    property  PingSequence: Word read FDstPort write FDstPort;
    property  UseRandomPingID: Boolean read FRandomSrcPort write FRandomSrcPort;
    property  UseRandomPingSequence: Boolean read FRandomDstPort write FRandomDstPort;
  end;

implementation

type
  // TCP/UDP pseudo-header
  // (used to calculate checksums)
  //
  TPseudoHeader = packed record
    saddr, daddr: DWORD;
    zero, protocol: BYTE;
    packetlen: WORD;
  end;

procedure DelayMS(ms: Integer);
//
// DelayMS() -- delay in milliseconds.
// We could have used Delphi's sleep() function,
// but if the delay is long sleep() will create
// this sinking feeling that the application is hung.
// Our DelayMS() function yields control
// by calling Application.ProcessMessages.
//
var StartTime: LongInt;
begin
  StartTime := GetTickCount;
  repeat
    Application.ProcessMessages;
  until (LongInt(GetTickCount)-StartTime >= ms) or (Application.Terminated)
end;

procedure RaiseException(msg: String; eCode: Integer);
//
// Format the message and throw a nice exception
//
  function AdditionalMessage: String;
  begin
    Result := SysErrorMessage(eCode);
    if Result <> '' then Result := ': ' + Result
  end;
begin
  if eCode = 0 then
    raise Exception.Create(msg)
  else
    raise Exception.Create('ERROR: '+msg+' [SocketError '+IntToStr(eCode)
                          +AdditionalMessage+']')
end;

{  TSenderIP }

constructor TSenderIP.Create;
begin
  FSocket := INVALID_SOCKET;
  Randomize  { seed the random number generator }
end;

destructor TSenderIP.Destroy;
begin
  CleanupWinsock(FSocket);
  inherited
end;

procedure TSenderIP.ThrowException(msg: String; eCode: Integer);
begin
  if eCode <> 0 then CleanupWinsock(FSocket);
  RaiseException(msg, eCode)
end;

procedure TSenderIP.Execute;
VAR opt: Integer;
    errStr: String;
    x: Boolean;
begin
  // Initialize WinSock. We are going to work with raw
  // sockets, so we require Winsock version 2.
  //
  errStr := InitWinsock(2,2);
  if errStr <> '' then  ThrowException(errStr, 0);

  if Assigned(FOnExecute) then
  begin
    case FProtocol of
       IPPROTO_UDP:   x := FOnExecute(Self, ptUDP);
       IPPROTO_ICMP:  x := FOnExecute(Self, ptICMP);
       else           x := FOnExecute(Self, ptTCP);
    end;
    if NOT x then
    begin
      CleanupWinsock;
      Exit
    end
  end;

  FSocket := socket(AF_INET, SOCK_RAW, IPPROTO_RAW);

  if (FSocket = INVALID_SOCKET) then
    ThrowException('Failed to open a RAW socket', WSAGetLastError());

  // With Winsock 2 IP_HDRINCL is as close we can get to "raw" sockets
  //
  // Note: IP_HDRINCL works at IPPROTO_IP level
  //
  opt := 1;
  if (setsockopt(FSocket, IPPROTO_IP, IP_HDRINCL, PChar(@opt), sizeof(opt)) = SOCKET_ERROR) then
    ThrowException('Error setting socket options', WSAGetLastError())
  else begin
    SendPackets; { do your thing... }
    CleanupWinsock(FSocket);
    PrintLine('Done.');
  end
end;

procedure TSenderIP.SetNumPackets(value: Word);
begin
  FNumPackets := value;
  if FNumPackets = 0 then  // 0 means max
    FMaxPackets := MaxWord
  else
    FMaxPackets := FNumPackets
end;

procedure TSenderIP.SetData(value: String);
begin
  FData := value;
  FDataLen := Length(FData)
end;

procedure TSenderIP.SetDelay(value: DWORD);
begin
  // Set minimum to 50 ms delay (of
  // course, this is an arbitrary number)
  //
  if value < 50 then  value := 50;
  FDelay := value
end;

procedure TSenderIP.SetSrcIP(value: String);
begin
  FSrcIP := ResolveHostAddress(value);
  if FSrcIP = DWORD(-1) then
  begin
    FSourceHost := '';
    ThrowException('Unknown Source host: '+ value, 0)
  end
  else begin
    FSourceHost := value;
    PrintLine('Using Source Host: '+value+'...');
  end;
end;

procedure TSenderIP.SetDstIP(value: String);
begin
  FDstIP := ResolveHostAddress(value);
  if FDstIP = DWORD(-1) then
  begin
    FDestinationHost := '';
    ThrowException('Unknown Destination host: '+ value, 0)
  end
  else begin
    FDestinationHost := value;
    PrintLine('Using Destination Host: '+value+'...');
  end;
end;

procedure TSenderIP.SendPackets;
  function GenerateFakeIP: String;
  VAR a, b, c, d: Integer;
  begin
    a := random(239)+1; // a >= 240 causes a socket error
    b := random(255);
    c := random(255);
    d := random(255);
    Result := Format('%d.%d.%d.%d', [a, b, c, d]);
  end;
VAR srcIP, dstIP: String;
    i: Integer;
begin
  for i := 1 to FMaxPackets do
  begin
    if FRandomSrcPort then { use high source ports }
      FSrcPort := random(5000-1024) + 1024;

    if FRandomDstPort then { use any dest ports }
      FDstPort := random($FFFF);

    srcIP := FSourceHost;
    dstIP := FDestinationHost;

    if FRandomSrcIP then
    begin
      srcIP := GenerateFakeIP;
      FSrcIP := ResolveHostAddress(srcIP);
    end;

    if FRandomDstIP then
    begin
      dstIP := GenerateFakeIP;
      FDstIP := ResolveHostAddress(dstIP);
    end;

    PrintLine('Sending: '+ srcIP+ ':'+ IntToStr(FSrcPort)+ ' -> '
                         + dstIP+ ':'+ IntToStr(FDstPort));

    Application.ProcessMessages;
    SendOnePacket;
    if i < FMaxPackets then  DelayMS(FDelay);
  end;
end;

procedure TSenderIP.SendOnePacket;
VAR errCode: Integer;
    ih: THdrIP;
    id: WORD;
begin
  // Create an IP header
  id := random($FFFF);

  FillChar(ih, sizeof(ih), 0);// clear
  SetIHver(ih, 4);            // IP version 4
  SetIHlen(ih, sizeof(ih));   // IP header length

  ih.tot_len  := htons(GetIHlen(ih) + GetLength); // total length
  ih.id       := htons(id);   // ID
  ih.ttl      := FTimeToLive; // time to live
  ih.protocol := FProtocol;   // protocol type
  ih.saddr    := FSrcIP;      // source IP
  ih.daddr    := FDstIP;      // destination IP
  ih.check    := CalculateChecksum(@ih, GetIHlen(ih)); // compute IP checksum

  errCode     := SendDatagram(ih, PChar(FData), FDataLen);

  if errCode = 0 then
    UpdateSequence
  else
    ThrowException('SendDatagram error',  errCode)
end;

procedure TSenderIP.UpdateSequence;
begin
  { do nothing }
end;

function  TSenderIP.SendToRemote(addr, port: Integer;
                                 buffer: PChar;
                                 len: Integer): Integer;
VAR remote: TSockAddrIn;
begin
  Result := 0;

 {$ifdef DUMP_MODE}
  // dump() can be pretty helpful for debugging...
  dump(buffer, len);
 {$endif}

  FillChar(remote, sizeof(remote), 0);
  remote.sin_family      := AF_INET;    { Internet domain }
  remote.sin_port        := port;
  remote.sin_addr.s_addr := addr;

  // send the datagram
  if (sendto(FSocket, buffer^, len, 0, TSockAddr(remote), sizeof(remote)) = SOCKET_ERROR) then
    Result := WSAGetLastError()
end;

procedure TSenderIP.PrintLine(s: String);
begin
  if Assigned(FOnPrintLine) then FOnPrintLine(s)
end;

{$ifdef DUMP_MODE}
VAR howmany: Integer = 1;   // Dump once
procedure TSenderIP.Dump(data: PByte; len: Integer);
VAR i: Integer;
    s: String;
begin
  if howmany = 0 then Exit;
  Dec(howmany);

  PrintLine('');
  PrintLine('DATA DUMP: Total length: '+IntToStr(len));

  s := '';
  for i := 0 to len-1 do
  begin
    s := s + Format('%02X ', [data^]);
    if ((i+1) mod 16 = 0) then  PrintLine(s);
    Inc(data);
  end;
  PrintLine(s);
  PrintLine('');
end;
{$endif} {DUMP_MODE}


{  TSenderTCP }

constructor TSenderTCP.Create;
begin
  inherited;
  FProtocol := IPPROTO_TCP
end;

function TSenderTCP.SendDatagram(ih: THdrIP; data: PChar; dlen: Integer): Integer;
VAR ph: TPseudoHeader;
    th: THdrTCP;
    len: Integer;
    p: PChar;
begin
  // Create TCP header
  FillChar(th, sizeof(th), 0);    // clear
  th.source   := htons(FSrcPort); // source port
  th.dest     := htons(FDstPort); // destination port
  th.seq      := htonl(FSequence);// sequence number
  th.ack_seq  := htonl(0);        // ack number

  SetTHdoff(th, sizeof(th));      // flags $0050
  SetTHflag(th, ftFIN, FFinFlag);
  SetTHflag(th, ftSYN, FSynFlag); // flags $0250
  SetTHflag(th, ftRST, FRstFlag);
  SetTHflag(th, ftPSH, FPshFlag);
  SetTHflag(th, ftACK, FAckFlag);
  SetTHflag(th, ftURG, FUrgFlag);
  th.window   := htons($FFFF);

  // compute TCP checksum...
  { The TCP checksum also covers a 96 bit pseudo header
    conceptually prefixed to the TCP header.  This pseudo
    header contains the Source Address, the Destination
    Address, the Protocol (occupies an octet), and TCP
    length. This gives the TCP protection against
    misrouted segments.
  }
  ph.saddr     := ih.saddr;
  ph.daddr     := ih.daddr;
  ph.zero      := 0;
  ph.protocol  := FProtocol;
  ph.packetlen := htons(sizeof(th) + dlen);

  p := @FIpBuffer;
  Move(ph, p^, sizeof(ph));
  Inc(p, sizeof(ph));
  Move(th, p^, sizeof(th));
  Inc(p, sizeof(th));
  Move(data^, p^, dlen);

  th.check := CalculateChecksum(@FIpBuffer, sizeof(ph) + sizeof(th) + dlen);

  // stuff the send buffer
  p := @FIpBuffer;
  len := GetIHlen(ih); // IP header length in bytes
  Move(ih, p^, len);
  Inc(p, len);
  Move(th, p^, sizeof(th));
  Inc(p, sizeof(th));
  Move(data^, p^, dlen);
  len := len + sizeof(th)+ dlen;

  Result := SendToRemote(ih.daddr, th.dest, @FIpBuffer, len);
end;

function  TSenderTCP.GetLength: Word;
begin
  Result := sizeof(THdrTCP) + FDataLen
end;

procedure TSenderTCP.UpdateSequence;
begin
  { sequence number will be increased by the amount
    of data octets (8-bit bytes) in the datagram }
  Inc(FSequence, FDataLen)
end;


{  TSenderUDP }

constructor TSenderUDP.Create;
begin
  inherited;
  FProtocol := IPPROTO_UDP
end;

function  TSenderUDP.GetLength: Word;
begin
  Result := sizeof(THdrUDP) + FDataLen
end;

function TSenderUDP.SendDatagram(ih: THdrIP; data: PChar; dlen: Integer): Integer;
VAR ph: TPseudoHeader;
    uh: THdrUDP;
    len: Integer;
    p: PChar;
begin
  // Create UDP header
  FillChar(uh, sizeof(uh), 0);    // clear
  uh.src_port := htons(FSrcPort); // source port
  uh.dst_port := htons(FDstPort); // destination port
  uh.length   := htons(sizeof(uh)+dlen);

  // compute UDP checksum...
  { The UDP checksum also covers a 96 bit pseudo header
    conceptually prefixed to the UDP header. See RFC 768
    for details
  }
  ph.saddr     := ih.saddr;
  ph.daddr     := ih.daddr;
  ph.zero      := 0;
  ph.protocol  := IPPROTO_UDP;
  ph.packetlen := htons(sizeof(uh)+dlen);

  p := @FIpBuffer;
  Move(ph, p^, sizeof(ph));
  Inc(p, sizeof(ph));
  Move(uh, p^, sizeof(uh));
  Inc(p, sizeof(uh));
  Move(data^, p^, dlen);

  uh.checksum := CalculateChecksum(@FIpBuffer, sizeof(ph) + sizeof(uh) + dlen);
  if uh.checksum = 0 then  uh.checksum := $FFFF;

  // stuff the send buffer
  p := @FIpBuffer;
  len := GetIHlen(ih); // IP header length in bytes
  Move(ih, p^, len);
  Inc(p, len);
  Move(uh, p^, sizeof(uh));
  Inc(p, sizeof(uh));
  Move(data^, p^, dlen);
  len := len + sizeof(uh)+ dlen;

  Result := SendToRemote(ih.daddr, uh.dst_port, @FIpBuffer, len);
end;


{  TSenderICMP  }

type
  THdrECHO = packed record  // ICMP Echo (Ping) header
    IcmpType: Byte;
    IcmpCode: Byte;
    checksum: WORD;
    id      : WORD;
    sequence: WORD;
  end;

constructor TSenderICMP.Create;
begin
  inherited;
  FProtocol := IPPROTO_ICMP
end;

function  TSenderICMP.GetLength: Word;
begin
  Result := sizeof(THdrEcho) + FDataLen
end;

function TSenderICMP.SendDatagram(ih: THdrIP; data: PChar; dlen: Integer): Integer;
VAR eh: THdrEcho;
    len: Integer;
    p: PChar;
begin
  // Create an ICMP/Ping header
  FillChar(eh, sizeof(eh), 0);    // clear
  eh.IcmpType := 8;               // ICMP type ECHO
  eh.IcmpCode := 0;
  eh.ID       := htons(FSrcPort);
  eh.Sequence := htons(FDstPort);

  // compute ICMP checksum...
  p := @FIpBuffer;
  Move(eh, p^, sizeof(eh));
  Inc(p, sizeof(eh));
  Move(data^, p^, dlen);

  eh.checksum := CalculateChecksum(@FIpBuffer, sizeof(eh) + dlen);

  // stuff the send buffer
  p := @FIpBuffer;
  len := GetIHlen(ih); // IP header length in bytes
  Move(ih, p^, len);
  Inc(p, len);
  Move(eh, p^, sizeof(eh));
  Inc(p, sizeof(eh));
  Move(data^, p^, dlen);
  len := len + sizeof(eh)+ dlen;

  Result := SendToRemote(ih.daddr, eh.id, @FIpBuffer, len);
end;

end.
