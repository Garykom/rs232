library AddInNative;

{$mode objfpc}{$H+}

uses
 {$IFDEF UNIX} {$IFDEF UseCThreads} cthreads,
  cmem, {$ENDIF} {$ENDIF}
  V8AddIn,
  RS232;

exports

  V8AddIn.GetClassNames,
  V8AddIn.GetClassObject,
  V8AddIn.DestroyObject,
  V8AddIn.SetPlatformCapabilities;

{$R *.res}

begin

  with TAddInRS232 do
  begin
    RegisterAddInClass('XYZRS232');

    AddFunc('PortNames', 'ИменаПортов', @GetPortNames);
    AddFunc('GetOpenPorts', 'ПолучитьОткрытыеПорты', @GetOpenPorts);

    AddFunc('OpenPort', 'ОткрытьПорт', @OpenPort);

    AddFunc('ConfigPort', 'НастроитьПорт', @ConfigPort, 7);

    AddFunc('GetDividers', 'ПолучитьРазделители', @GetDividers);
    AddFunc('SetDividers', 'УстановитьРазделители', @SetDividers);

    AddFunc('GetMaxBufferLength', 'ПолучитьДлинуБуфера',
      @GetMaxBufferLength);
    AddFunc('SetMaxBufferLength', 'УстановитьДлинуБуфера',
      @SetMaxBufferLength);

    AddFunc('ClosePort', 'ЗакрытьПорт', @ClosePort);
    AddFunc('SendString', 'ОтправитьСтроку', @SendString);
    AddProc('SetLogFile', 'УстановитьФайлЛога', @SetLogFile);
  end;

end.
