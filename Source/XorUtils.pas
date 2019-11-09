unit XorUtils;

interface

uses
  Classes;

  procedure XorData(Input : TStream; const Key : String; Output : TStream); overload;
  procedure XorData(Input : TStream; BufferSize : Cardinal; const Key : String; Output : TStream); overload;
  procedure XorData(Input : TStream; Count : Int64; BufferSize : Cardinal;
    const Key : String; Output : TStream); overload;

implementation

uses
  SysUtils, Math;

type

  TXorableOrdinal = Int64;

  TBufferElement = TXorableOrdinal;
  PBufferElement = ^TBufferElement;
  TBuffer = array of TBufferElement;

  TKeyElement = TXorableOrdinal;
  TKey = array of TKeyElement;

const

  BUFFER_ELEMENT_SIZE = SizeOf(TBufferElement);
  KEY_ELEMENT_SIZE = SizeOf(TKeyElement);

  DEFAULT_BUFFER_SIZE : Cardinal = 16 * 1024 * 1024;  // 16 MB
  DEFAULT_COUNT : Int64 = -1; // ALL

{ INTERNAL }

procedure CheckParams(Input : TStream; Count : Int64; BufferSize : Cardinal;
  const Key : String; Output : TStream);
begin
  Assert(Input <> nil, 'Input = nil');
  Assert(Count >= -1, 'Count < -1');
  Assert(BufferSize mod BUFFER_ELEMENT_SIZE = 0, 'Invalid BufferSize');
  Assert(Length(Key) > 0, 'Key = <empty>');
  Assert(Output <> nil, 'Output = nil');
  Assert(Input <> Output, 'Input = Output');
end;

function CreateBuffer(BufferSize : Cardinal) : TBuffer;
begin
  SetLength(Result, BufferSize div BUFFER_ELEMENT_SIZE);
end;

function CreateKey(const Key : String) : TKey;
var
  iKeySize : Integer;
  {$IFDEF UNICODE}
  RawKeyBytes, SignificantKeyBytes : TBytes;
  KeyByte : Byte;
  {$ENDIF}
begin
  iKeySize := Length(Key) * SizeOf(Char);

  {$IFDEF UNICODE}
  SetLength(RawKeyBytes, iKeySize);
  SetLength(SignificantKeyBytes, iKeySize);

  Move(Key[1], RawKeyBytes[0], iKeySize);
  iKeySize := 0;
  for KeyByte in RawKeyBytes do
    if KeyByte <> 0 then
    begin
      SignificantKeyBytes[iKeySize] := KeyByte;
      Inc(iKeySize);
    end;
  {$ENDIF}

  SetLength(Result, iKeySize div KEY_ELEMENT_SIZE + 1);
  Move({$IFDEF UNICODE}SignificantKeyBytes[0]{$ELSE}Key[1]{$ENDIF}, Result[0], iKeySize);
end;

function GetActualCount(Input : TStream; Count : Int64) : Int64;
begin
  Result := Input.Size - Input.Position;
  if Count <> DEFAULT_COUNT then
    Result := Min(Result, Count);
end;

function XorElement(Element : TBufferElement; const Key : TKey) : TBufferElement; {$IFNDEF DEBUG}inline;{$ENDIF}
var
  i : Integer;
begin
  Result := Element;
  for i := 0 to High(Key) do
    Result := Result xor Key[i];
end;

procedure XorBuffer(const Input : TBuffer; Count : Integer; const Key : TKey; const Output : TBytes); {$IFNDEF DEBUG}inline;{$ENDIF}
var
  iElementCount, iRemainderSize, iOutputOffset, i : Integer;
  XoredElement : TBufferElement;
  pRemainder : PBufferElement;
begin
  iElementCount  := Count div BUFFER_ELEMENT_SIZE;
  iRemainderSize := Count mod BUFFER_ELEMENT_SIZE;
  iOutputOffset  := 0;

  for i := 0 to iElementCount - 1 do
  begin
    XoredElement := XorElement(Input[i], Key);
    Move(XoredElement, Output[iOutputOffset], BUFFER_ELEMENT_SIZE);
    Inc(iOutputOffset, BUFFER_ELEMENT_SIZE);
  end;

  if iRemainderSize > 0 then
  begin
    FillChar(XoredElement, BUFFER_ELEMENT_SIZE, 0);

    pRemainder := @Input[0];
    Inc(pRemainder, iElementCount);
    Move(pRemainder^, XoredElement, iRemainderSize);

    XoredElement := XorElement(XoredElement, Key);
    Move(XoredElement, Output[iOutputOffset], iRemainderSize);
  end;
end;

procedure XorData(Input : TStream; Count : Int64; const Buffer : TBuffer;
  const Key : TKey; Output : TStream); overload;
var
  iBufferSize, iChunkSize : Integer;
  XoredChunk : TBytes;
begin
  if Count = 0 then
    Exit;

  iBufferSize := Length(Buffer) * BUFFER_ELEMENT_SIZE;
  repeat
    FillChar(Buffer[0], iBufferSize, 0);
    iChunkSize := Input.Read(Buffer[0], iBufferSize);
    if iChunkSize <= 0 then
      Break;

    SetLength(XoredChunk, iChunkSize);
    FillChar(XoredChunk[0], iChunkSize, 0);
    XorBuffer(Buffer, iChunkSize, Key, XoredChunk);
    Output.WriteBuffer(XoredChunk[0], iChunkSize);

    Dec(Count, iChunkSize);
  until Count <= 0;
end;

{ PUBLIC }

procedure XorData(Input : TStream; const Key : String; Output : TStream);
begin
  XorData(Input, DEFAULT_BUFFER_SIZE, Key, Output);
end;

procedure XorData(Input : TStream; BufferSize : Cardinal; const Key : String; Output : TStream);
begin
  XorData(Input, DEFAULT_COUNT, BufferSize, Key, Output);
end;

procedure XorData(Input : TStream; Count : Int64; BufferSize : Cardinal;
  const Key : String; Output : TStream);
begin
  CheckParams(Input, Count, BufferSize, Key, Output);
  XorData(Input, GetActualCount(Input, Count), CreateBuffer(BufferSize), CreateKey(Key), Output);
end;

end.
