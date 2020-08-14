unit RS232;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, V8AddIn, fpTimer, FileUtil, LazUTF8, Synaser, contnrs;

type

  { TSendExternalEvent }

  TSendExternalEvent = procedure(Sender: TObject; Message, Data: string) of object;

  { TBlockSerialThread }

  TBlockSerialThread = class(TThread)
  private
    buffer: string;
    countReceive: integer;
    receive: array[0..10000] of byte;
  public
    Device: string;
    Serial: TBlockSerial;
    MaxBufferLength: integer;
    IntervalReceive: integer;
    IntervalSendTo1C: integer;
    Dividers: string;
    OnExternalEvent: TSendExternalEvent;
    procedure SendDataTo1C();
    procedure Execute; override;
  end;

  { TAddInRS232 }

  TAddInRS232 = class(TAddIn)
  private
    FLogFilePath: string;
    FSerialThreads: TObjectList;
    function GetSerialThread(Device: string; Creating: boolean): TBlockSerialThread;
    procedure MyExternalEventProc(Sender: TObject; Message, Data: string);
    //procedure MyTimerProc(Sender: TObject);
    procedure Log(Message: string);
  public
    function GetPortNames: variant;
    function GetOpenPorts: variant;
    function OpenPort(DeviceName: variant): variant;
    function ConfigPort(const Params: array of variant): variant;
    function ClosePort(DeviceName: variant): variant;
    function SendString(DeviceName: variant; Message: variant): variant;

    function GetDividers(DeviceName: variant): variant;
    function SetDividers(DeviceName: variant; Dividers: variant): variant;

    function GetMaxBufferLength(DeviceName: variant): variant;
    function SetMaxBufferLength(DeviceName: variant; MaxBufferLength: variant): variant;

    //procedure ShowInStatusLine(Text: variant);

    procedure SetLogFile(FilePath: variant);
    constructor Create; override;
    destructor Destroy; override;
    //function LoadPicture(FileName: variant): variant;
    //procedure ShowMessageBox;
  end;

implementation

procedure LogToFile(LogFilePath, Message: string);
var
  F: TextFile;
begin
  AssignFile(F, LogFilePath);
  if FileExists(LogFilePath) then
    Append(F)
  else
    Rewrite(F);

  WriteLn(F, '' + DateTimeToStr(Now) + ': ' + Message);
  CloseFile(F);
end;

{ TBlockSerialThread }

procedure TBlockSerialThread.SendDataTo1C();
var
  iChar, iByte, iDivider: integer;
  SDivider: string;
  SDividers: TStringList;
  SSendNow: boolean;
begin
  SDividers := TStringList.Create;
  SDivider := '';
  for iChar := 1 to Length(Dividers) do
  begin
    if Dividers[iChar] = ',' then
    begin
      if SDivider <> '' then
      begin
        SDividers.Add(SDivider);
        SDivider := '';
      end;
    end
    else
      SDivider := SDivider + Dividers[iChar];
  end;
  if SDivider <> '' then
    SDividers.Add(SDivider);

  for iByte := 0 to countReceive - 1 do
  begin
    SSendNow := False;
    buffer := buffer + char(receive[iByte]);

    if ((MaxBufferLength > 0) and (Length(buffer) >= MaxBufferLength)) or
      (Length(buffer) >= 9999) then
    begin
      SSendNow := True;
    end;

    for iDivider := 0 to SDividers.Count - 1 do
    begin
      if (SDividers[iDivider] <> '') and (buffer.EndsWith(SDividers[iDivider])) then
      begin
        SSendNow := True;
      end;
    end;

    if SSendNow then
    begin
      OnExternalEvent(Self, Device, buffer);
      sleep(200);
      buffer := '';
    end;
  end;
end;

procedure TBlockSerialThread.Execute;
begin
  repeat
    if Serial = nil then
    begin
      OnExternalEvent(Self, Serial.Device, IntToStr(Serial.LastError) +
        '-' + Serial.LastErrorDesc);
      Break;
    end;

    Sleep(IntervalReceive);

    if Serial <> nil then
    begin
      countReceive := Serial.WaitingDataEx();
      if countReceive > 0 then
      begin
        Serial.RecvBuffer(@receive, countReceive);
        SendDataTo1C;
      end;
    end;
    if Terminated then
      Break;
  until Terminated;
end;

{ TAddInRS232 }

procedure TAddInRS232.SetLogFile(FilePath: variant);
begin
  FLogFilePath := UTF8ToSys(string(FilePath));
end;

procedure TAddInRS232.Log(Message: string);
begin
  //FLogFilePath := 'C:\Users\Gary\Desktop\XYZ\ВК_RS232_TBlockSerial\log.txt';

  if FLogFilePath <> '' then
    LogToFile(FLogFilePath, Message);
end;

procedure TAddInRS232.MyExternalEventProc(Sender: TObject; Message, Data: string);
begin
  ExternalEvent('XYZ RS232', Message, Data);
end;

function TAddInRS232.GetPortNames: variant;
begin
  Result := GetSerialPortNames();
end;

function TAddInRS232.GetSerialThread(Device: string;
  Creating: boolean): TBlockSerialThread;
var
  i: integer;
  SSerialThread: TBlockSerialThread;
begin
  Log('GetSerialThread: ' + Device);
  SSerialThread := nil;
  if FSerialThreads = nil then
  begin
    Log('GetSerialThread: 1');
    FSerialThreads := TObjectList.Create;
  end;

  Log('GetSerialThread: 2');
  for i := 0 to FSerialThreads.Count - 1 do
  begin
    Log('GetSerialThread: 3');
    if (FSerialThreads.Items[i] as TBlockSerialThread).Device = Device then
    begin
      Log('GetSerialThread: 4');
      SSerialThread := (FSerialThreads.Items[i] as TBlockSerialThread);
      Log('GetSerialThread: 5');
    end;
  end;
  Log('GetSerialThread: 6');
  if (SSerialThread = nil) and Creating then
  begin
    Log('GetSerialThread: 7');
    SSerialThread := TBlockSerialThread.Create(True);

    SSerialThread.Device := Device;
    SSerialThread.IntervalReceive := 50;
    SSerialThread.IntervalSendTo1C := 5000;
    SSerialThread.Priority := tpLowest;
    SSerialThread.buffer := '';
    SSerialThread.OnExternalEvent := @MyExternalEventProc;

    SSerialThread.Serial := TBlockSerial.Create;
    SSerialThread.Serial.LinuxLock := False;
    SSerialThread.Serial.RaiseExcept := True;

    FSerialThreads.Add(SSerialThread);
    Log('GetSerialThread: 8');
  end;

  Result := SSerialThread;
  Log('GetSerialThread: ' + Device);
end;

function TAddInRS232.GetOpenPorts: variant;
var
  i: integer;
  SSerialThread: TBlockSerialThread;
begin
  Log('GetOpenPorts: 1');
  Result := '';
  SSerialThread := nil;
  if FSerialThreads = nil then
  begin
    Log('GetOpenPorts: 2');
    FSerialThreads := TObjectList.Create;
  end;

  Log('GetOpenPorts: 3');
  for i := 0 to FSerialThreads.Count - 1 do
  begin
    SSerialThread := (FSerialThreads.Items[i] as TBlockSerialThread);
    Log('GetOpenPorts: 4');
    if Result = '' then
      Result := SSerialThread.Device
    else
      Result := Result + ',' + SSerialThread.Device;
  end;
  Log('GetOpenPorts: 5');
end;

function TAddInRS232.OpenPort(DeviceName: variant): variant;
var
  SDevice: string;
  SSerialThread: TBlockSerialThread;
begin
  SDevice := UTF8ToSys(string(DeviceName));
  Log('OpenPort: ' + SDevice);
  SSerialThread := GetSerialThread(SDevice, True);

  try
    Log('OpenPort: 1');
    SSerialThread.Serial.Connect(SDevice);
    Log('OpenPort: 2');
    sleep(50);

    Log('OpenPort: 3');
    SSerialThread.Serial.EnableRTSToggle(True);
    SSerialThread.Serial.Config(9600, 8, 'N', 0, False, False);

    //sleep(50);
    Log('OpenPort: 4');
    SSerialThread.Start;

    Result := True;
    Log('OpenPort: 5');
  except
    Log('OpenPort: except');
    ExternalEvent('RS223', SDevice, 'Error: ' +
      IntToStr(SSerialThread.Serial.LastError) + '-' +
      SSerialThread.Serial.LastErrorDesc);
    Result := False;
  end;
  Log('OpenPort: ' + SDevice);
end;

function TAddInRS232.ConfigPort(const Params: array of variant): variant;
var
  SDevice: string;
  SSerialThread: TBlockSerialThread;
  SBoud: integer;
  SBits: integer;
  SParity: char;
  SStop: integer;
  SSoftFlow, SHardFlow: boolean;

begin
  SDevice := UTF8ToSys(string(Params[0]));
  SBoud := integer(Params[1]);
  SBits := integer(Params[2]);
  SParity := string(Params[3])[1];
  SStop := integer(Params[4]);
  SSoftFlow := boolean(Params[5]);
  SHardFlow := boolean(Params[6]);

  SSerialThread := GetSerialThread(SDevice, False);
  try
    //SSerialThread.Serial.Config(9600, 8, 'N', 0, False, False);
    SSerialThread.Serial.Config(SBoud, SBits, SParity, SStop, SSoftFlow, SHardFlow);
    Result := True;
  except
    Result := False;
  end;
end;

function TAddInRS232.GetDividers(DeviceName: variant): variant;
var
  SDevice: string;
  SSerialThread: TBlockSerialThread;
begin
  SDevice := UTF8ToSys(string(DeviceName));

  SSerialThread := GetSerialThread(SDevice, False);
  Result := '';
  if SSerialThread <> nil then
    Result := SSerialThread.Dividers;
end;

function TAddInRS232.SetDividers(DeviceName: variant; Dividers: variant): variant;
var
  SDevice: string;
  SSerialThread: TBlockSerialThread;
  SDividers: string;
begin
  SDevice := UTF8ToSys(string(DeviceName));
  SDividers := UTF8ToSys(string(Dividers));
  Result := False;
  SSerialThread := GetSerialThread(SDevice, False);

  if SSerialThread <> nil then
  begin
    SSerialThread.Dividers := SDividers;
    Result := True;
  end;
end;

function TAddInRS232.GetMaxBufferLength(DeviceName: variant): variant;
var
  SDevice: string;
  SSerialThread: TBlockSerialThread;
begin
  SDevice := UTF8ToSys(string(DeviceName));

  SSerialThread := GetSerialThread(SDevice, False);
  Result := 0;
  if SSerialThread <> nil then
    Result := SSerialThread.MaxBufferLength;
end;

function TAddInRS232.SetMaxBufferLength(DeviceName: variant;
  MaxBufferLength: variant): variant;
var
  SDevice: string;
  SSerialThread: TBlockSerialThread;
  SMaxBufferLength: integer;
begin
  SDevice := UTF8ToSys(string(DeviceName));
  SMaxBufferLength := integer(MaxBufferLength);
  Result := False;
  SSerialThread := GetSerialThread(SDevice, False);

  if SSerialThread <> nil then
  begin
    SSerialThread.MaxBufferLength := SMaxBufferLength;
    Result := True;
  end;
end;

function TAddInRS232.ClosePort(DeviceName: variant): variant;
var
  SDevice: string;
  SSerialThread: TBlockSerialThread;
begin
  SDevice := UTF8ToSys(string(DeviceName));
  Log('ClosePort: ' + SDevice);
  SSerialThread := GetSerialThread(SDevice, False);
  FSerialThreads.Remove(SSerialThread);
  try
    Log('ClosePort 1');
    if SSerialThread <> nil then
    begin
      Log('ClosePort 2');
      if SSerialThread.Serial <> nil then
      begin
        Log('ClosePort 3');
        SSerialThread.Serial.CloseSocket;
        SSerialThread.Serial.Free;
      end;
      SSerialThread.Terminate;
      FreeAndNil(SSerialThread);
      Log('ClosePort 4');
    end;
    Result := True;
  except
    Result := False;
    Log('ClosePort except');
  end;
  Log('ClosePort: ' + SDevice);
end;

function TAddInRS232.SendString(DeviceName: variant; Message: variant): variant;
var
  SDevice: string;
  SMessage: string;
  SSerialThread: TBlockSerialThread;
begin
  SDevice := UTF8ToSys(string(DeviceName));
  SMessage := UTF8ToSys(string(Message));

  Log('SendString: ' + SDevice);
  SSerialThread := GetSerialThread(SDevice, False);
  Log('SendString 1');
  try
    if SSerialThread <> nil then
    begin
      Log('SendString 2');
      SSerialThread.Serial.SendString(SMessage);
    end;
    Result := True;
  except
    Result := False;
    Log('SendString except');
  end;
  Log('SendString: ' + SDevice);
end;

constructor TAddInRS232.Create;
begin
  //inherited Create;
  self.FLogFilePath := '';
end;

destructor TAddInRS232.Destroy;
var
  i: integer;
  SSerialThread: TBlockSerialThread;
begin
  if FSerialThreads <> nil then
  begin
    for i := 0 to FSerialThreads.Count - 1 do
    begin
      SSerialThread := (FSerialThreads.Items[i] as TBlockSerialThread);
      ClosePort(SSerialThread.Device);
    end;

    FreeAndNil(FSerialThreads);
  end;

  inherited Destroy;
end;

end.
