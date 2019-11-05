program XorFiles;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Windows,
  Classes,
  SysUtils,
  StrUtils,
  XorUtils in 'XorUtils.pas';

function ChangeFileExt(const FileName : String; Xored : Boolean) : String;
const
  ARR_EXTENSIONS : array [Boolean] of String = ('.unxored', '.xored');
begin
  if EndsText(ARR_EXTENSIONS[Xored], FileName) then
    Result := FileName
  else
  if EndsText(ARR_EXTENSIONS[not Xored], FileName) then
    Result := SysUtils.ChangeFileExt(FileName, ARR_EXTENSIONS[Xored])
  else
    Result := FileName + ARR_EXTENSIONS[Xored];
end;

procedure ExcludePreviouslyProducedFiles(FileNames : TStringList);
var
  L : TStringList;
  i : Integer;
  sFileName, sXoredFileName, sUnXoredFileName : String;
begin
  L := TStringList.Create;
  try
    L.Assign(FileNames);

    i := 0;
    while i < L.Count do
    begin
      sFileName        := L[i];
      sXoredFileName   := ChangeFileExt(sFileName, True);
      sUnXoredFileName := ChangeFileExt(sFileName, False);

      if SameText(sFileName, sXoredFileName) or SameText(sFileName, sUnXoredFileName) then
        L.Delete(i)
      else
        Inc(i);
    end;

    FileNames.Assign(L);
  finally
    L.Free;
  end;
end;

procedure ProcessFile(const FileName : String; const Key : String);
var
  InFS, XoredFS, UnXoredFS : TFileStream;
begin
  InFS := TFileStream.Create(FileName, fmOpenRead + fmShareDenyWrite);
  try
    XoredFS := TFileStream.Create(ChangeFileExt(FileName, True), fmCreate);
    try
      XorData(InFS, Key, XoredFS);

      UnXoredFS := TFileStream.Create(ChangeFileExt(FileName, False), fmCreate);
      try
        XoredFS.Position := 0;
        XorData(XoredFS, Key, UnXoredFS);
      finally
        UnXoredFS.Free;
      end;
    finally
      XoredFS.Free;
    end;
  finally
    InFS.Free;
  end;
end;

const
  faNormal = {$IF CompilerVersion >= 20.0}SysUtils.faNormal{$ELSE}$00000080{$IFEND};
var
  sDir, sKey : String;
  SR : TSearchRec;
  FileNames : TStringList;
  sFileName : String;
  iBenchmark : Cardinal;
begin
  try
    sDir := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0)));
    Writeln('Working directory: ', sDir);

    Writeln('Enter key:');
    Readln(sKey);
    Writeln('Key: ', sKey);

    FileNames := TStringList.Create;
    try
      if FindFirst(sDir + '*', faNormal, SR) = S_OK then
        try
          repeat
            FileNames.Add(sDir + SR.Name);
          until FindNext(SR) <> S_OK;
        finally
          FindClose(SR);
        end;
      ExcludePreviouslyProducedFiles(FileNames);
      Writeln('Found files: ', FileNames.Count);

      for sFileName in FileNames do
      begin
        Writeln('Processing: ', ExtractFileName(sFileName));

        iBenchmark := GetTickCount;
        ProcessFile(sFileName, sKey);
        iBenchmark := GetTickCount - iBenchmark;

        Writeln('Processed: ', iBenchmark, ' ms (~', iBenchmark div 2, ' ms per operation)');
      end;
    finally
      FileNames.Free;
    end;

    Writeln('Press any key to exit...');
    Readln;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      Readln;
    end;
  end;
end.
