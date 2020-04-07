unit FrameClock;

{$IF Defined(WINDOWS) or Defined(MSWINDOWS)}
  {$DEFINE Windows}
{$ELSEIF Defined(LINUX) and Defined(FPC)}
  {$DEFINE Linux}
{$ELSE}
  {$MESSAGE FATAL 'Unsupported operating system.'}
{$IFEND}

{$IFDEF FPC}
  {$MODE ObjFPC}{$H+}
{$ENDIF}

interface

uses
  SysUtils,
  AuxTypes, AuxClasses;

type
  EFCException = class(Exception);

  EFCSystemException  = class(EFCException);
  EFCInvalidList      = class(EFCException);
  EFCIndexOutOfBounds = class(EFCException);

{===============================================================================
--------------------------------------------------------------------------------
                                   TFrameClock
--------------------------------------------------------------------------------
===============================================================================}
type
  TFCTicks = Int64;

  TFCFrameTime = record
    Ticks:  TFCTicks;
    Sec:    Double;   // seconds
    MiS:    Double;   // milliseconds
    UiS:    Double;   // microseconds
    iSec:   Int64;    // integral seconds
    iMiS:   Int64;    // integral milliseconds
    iUiS:   Int64;    // integral microseconds
  end;

// types and constants for lists...
type
  TFCTimeStamp = record
    Name:     String;
    Value:    TFCTicks;
    UserData: PtrInt;
  end;
  PFCTimeStamp = ^TFCTimeStamp;

const
  FC_LIST_IDX_TIMESTAMPS = 0;

{===============================================================================
    TFrameClock - class declaration
===============================================================================}
type
  TFrameClock = class(TCustomMultiListObject)
  protected
    fHighResolution:  Boolean;
    fFrequency:       Int64;      // [Hz]
    fResolution:      Int64;      // [ns]
    fFrameCounter:    Int64;      // number of measured frames
    fCreationTicks:   TFCTicks;
    fPrevFrameTicks:  TFCTicks;
    fCurrFrameTicks:  TFCTicks;
    fFrameTime:       TFCFrameTime;
    fTimeStamps:      array of TFCTimeStamp;
    fTimeStampCount:  Integer;
    // getters/setters
    Function GetCreationTime: TFCFrameTime; virtual;
    Function GetActualTime: TFCFrameTime; virtual;
    // list getters/setters
    Function GetTimeStamp(Index: Integer): TFCTimeStamp; virtual;
    procedure SetTimeStamp(Index: Integer; Value: TFCTimeStamp); virtual;
    Function GetTimeStampPtr(Index: Integer): PFCTimeStamp; virtual;
    // lists methods
    Function GetCapacity(List: Integer): Integer; override;
    procedure SetCapacity(List,Value: Integer); override;
    Function GetCount(List: Integer): Integer; override;
    procedure SetCount(List,Value: Integer); override;
    // other protected methods
    Function GetCurrentTicks: TFCTicks; virtual;
    Function GetTicksDiff(A,B: TFCTicks): TFCTicks; virtual;
    procedure FrameTimeFromTicks(var FrameTime: TFCFrameTime); virtual;
    procedure InitializeTime; virtual;
    procedure Initialize; virtual;
    procedure Finalize; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    Function TickFrame: TFCFrameTime; virtual;
  {
    TicksTime - returns time between given ticks and current frame
  }
    Function TicksTime(Ticks: TFCTicks): TFCFrameTime; virtual;
    Function LowIndex(List: Integer): Integer; override;
    Function HighIndex(List: Integer): Integer; override;
    // timestamps list
    Function TimeStampLowIndex: Integer; virtual;
    Function TimeStampHighIndex: Integer; virtual;
    Function TimeStampCheckIndex(Index: Integer): Boolean; virtual;
    Function TimeStampIndexOf(const Name: String): Integer; overload; virtual;
    Function TimeStampIndexOf(Value: TFCTicks): Integer; overload; virtual;
    Function TimeStampIndexOf(const Name: String; Value: TFCTicks): Integer; overload; virtual;
    Function TimeStampAdd(const Name: String; Value: TFCTicks; UserData: PtrInt = 0): Integer; virtual;
  {
    TimeStampAddCurrent - adds current frame ticks as a new timestamp
  }
    Function TimeStampAddCurrent(const Name: String; UserData: PtrInt = 0): Integer; virtual;
    procedure TimeStampInsert(Index: Integer; const Name: String; Value: TFCTicks; UserData: PtrInt = 0); virtual;
    Function TimeStampRemove(const Name: String): Integer; overload; virtual;
    Function TimeStampRemove(Value: Int64): Integer; overload; virtual;
    Function TimeStampRemove(const Name: String; Value: TFCTicks): Integer; overload; virtual;
    procedure TimeStampDelete(Index: Integer); virtual;
    procedure TimeStampClear; virtual;
  {
    TimeStampTime - returns time between selected timestamp and current frame 
  }
    Function TimeStampTime(Index: Integer): TFCFrameTime; virtual;

    property HighResolution: Boolean read fHighResolution;
    property Frequency: Int64 read fFrequency;
    property Resolution: Int64 read fResolution;
    property FrameCounter: Int64 read fFrameCounter;
    property CreationTicks: TFCTicks read fCreationTicks;
    property PrevFrameTicks: TFCTicks read fPrevFrameTicks;
    property CurrFrameTicks: TFCTicks read fCurrFrameTicks;
  {
    CreationTime - time from object creation to current frame end
  }
    property CreationTime: TFCFrameTime read GetCreationTime;
  {
    FrameTime - time from previous frame end to current frame end
  }
    property FrameTime: TFCFrameTime read fFrameTime;
  {
    ActualTime - time from previous frame end to actual time (moment the
                 property is accessed)
  }
    property ActualTime: TFCFrameTime read GetActualTime;
    // timestamps
    property TimeStampCount: Integer index FC_LIST_IDX_TIMESTAMPS read GetCount write SetCount;
    property TimeStampCapacity: Integer index FC_LIST_IDX_TIMESTAMPS read GetCapacity write SetCapacity;
    property TimeStamps[Index: Integer]: TFCTimeStamp read GetTimeStamp write SetTimeStamp; default;
  end;

{===============================================================================
    Standalone functions - declaration
===============================================================================}

type
  TClockMeasuringContext = type Pointer;

  TClockMeasuringUnit = (mruTick,mruSecond,mruMilli,mruMicro);

procedure ClockMeasuringStart(out Context: TClockMeasuringContext);
Function ClockMeasuringTick(var Context: TClockMeasuringContext; ReturnUnit: TClockMeasuringUnit = mruMilli): Int64;
Function ClockMeasuringEnd(var Context: TClockMeasuringContext; ReturnUnit: TClockMeasuringUnit = mruMilli): Int64;

implementation

uses
{$IFDEF Windows}Windows{$ELSE}baseunix, linux{$ENDIF};


{===============================================================================
--------------------------------------------------------------------------------
                                   TFrameClock
--------------------------------------------------------------------------------
===============================================================================}

const
  FC_MILLIS_PER_SEC = 1000;         // milliseconds per second
  FC_MICROS_PER_SEC = 1000000;      // microseconds per second
  FC_NANOS_PER_SEC  = 1000000000;   // nanoseconds per second

  FC_NANOS_PER_MILLI = 1000000;     // nanoseconds per millisecond
  FC_MILLIS_PER_DAY  = 86400000;    // milliseconds per day

{===============================================================================
    TFrameClock - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    TFrameClock - protected methods
-------------------------------------------------------------------------------}

Function TFrameClock.GetCreationTime: TFCFrameTime;
begin
Result.Ticks := GetTicksDiff(fCreationTicks,fCurrFrameTicks);
FrameTimeFromTicks(Result);
end;

//------------------------------------------------------------------------------

Function TFrameClock.GetActualTime: TFCFrameTime;
begin
Result.Ticks := GetTicksDiff(fPrevFrameTicks,GetCurrentTicks);
FrameTimeFromTicks(Result);
end;

//------------------------------------------------------------------------------

Function TFrameClock.GetTimeStamp(Index: Integer): TFCTimeStamp;
begin
If TimeStampCheckIndex(Index) then
  Result := fTimeStamps[Index]
else
  raise EFCIndexOutOfBounds.CreateFmt('TFrameClock.GetTimeStamp: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

procedure TFrameClock.SetTimeStamp(Index: Integer; Value: TFCTimeStamp);
begin
If TimeStampCheckIndex(Index) then
  fTimeStamps[Index] := Value
else
  raise EFCIndexOutOfBounds.CreateFmt('TFrameClock.SetTimeStamp: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

Function TFrameClock.GetTimeStampPtr(Index: Integer): PFCTimeStamp;
begin
If TimeStampCheckIndex(Index) then
  Result := Addr(fTimeStamps[Index])
else
  raise EFCIndexOutOfBounds.CreateFmt('TFrameClock.GetTimeStampPtr: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

Function TFrameClock.GetCapacity(List: Integer): Integer;
begin
case List of
  FC_LIST_IDX_TIMESTAMPS: Result := Length(fTimeStamps);
else
  raise EFCInvalidList.CreateFmt('TFrameClock.GetCapacity: Invalid list (%d).',[List]);
end;
end;

//------------------------------------------------------------------------------

procedure TFrameClock.SetCapacity(List,Value: Integer);
begin
case List of
  FC_LIST_IDX_TIMESTAMPS: begin
                            If Value < fTimeStampCount then
                              fTimeStampCount := Value;
                            SetLength(fTimeStamps,Value);
                          end;
else
  raise EFCInvalidList.CreateFmt('TFrameClock.SetCapacity: Invalid list (%d).',[List]);
end;
end;

//------------------------------------------------------------------------------

Function TFrameClock.GetCount(List: Integer): Integer;
begin
case List of
  FC_LIST_IDX_TIMESTAMPS: Result := fTimeStampCount;
else
  raise EFCInvalidList.CreateFmt('TFrameClock.GetCount: Invalid list (%d).',[List]);
end;
end;

//------------------------------------------------------------------------------

procedure TFrameClock.SetCount(List,Value: Integer);
begin
case List of
  FC_LIST_IDX_TIMESTAMPS:;  // do nothing
else
  raise EFCInvalidList.CreateFmt('TFrameClock.SetCount: Invalid list (%d).',[List]);
end;
end;

//------------------------------------------------------------------------------

Function TFrameClock.GetCurrentTicks: TFCTicks;
{$IFNDEF Windows}
var
  Time: TTimeSpec;
{$ENDIF}
begin
Result := 0;
If fHighResolution then
  begin
  {$IFDEF Windows}
    If QueryPerformanceCounter(Result) then
      Result := Result and $7FFFFFFFFFFFFFFF  // mask out sign bit
    else
      raise EFCSystemException.CreateFmt('TFrameClock.GetCurrentTicks: System error 0x%.8x.',[GetLastError]);
  {$ELSE}
    If clock_gettime(CLOCK_MONOTONIC_RAW,@Time) = 0 then
      Result := (Int64(Time.tv_sec) * FC_NANOS_PER_SEC) + Time.tv_nsec
    else
      raise EFCSystemException.CreateFmt('TFrameClock.GetCurrentTicks: System error %d.',[errno]);
  {$ENDIF}
  end
else Result := Int64(Trunc(Now * FC_MILLIS_PER_DAY));
end;

//------------------------------------------------------------------------------

Function TFrameClock.GetTicksDiff(A,B: TFCTicks): TFCTicks;
begin
If A < B then
  Result := B - A
else If A > B then
  Result := High(Int64) - A + B + 1{overflow tick}
else
  Result := 0;
end;

//------------------------------------------------------------------------------

procedure TFrameClock.FrameTimeFromTicks(var FrameTime: TFCFrameTime);
begin
FrameTime.Sec := FrameTime.Ticks / fFrequency;
FrameTime.MiS := FrameTime.Sec * FC_MILLIS_PER_SEC;
FrameTime.UiS := FrameTime.Sec * FC_MICROS_PER_SEC;
FrameTime.iSec := Trunc(FrameTime.Sec);
FrameTime.iMiS := Trunc(FrameTime.MiS);
FrameTime.iUiS := Trunc(FrameTime.UiS);
end;

//------------------------------------------------------------------------------

procedure TFrameClock.InitializeTime;
{$IFNDEF Windows}
var
  Time: TTimeSpec;
{$ENDIF}
begin
{$IFDEF Windows}
If QueryPerformanceFrequency(fFrequency) then
  begin
    fHighResolution := True;
    fFrequency := fFrequency and $7FFFFFFFFFFFFFFF; // mask out sign bit
    fResolution := Trunc((1 / fFrequency) * FC_NANOS_PER_SEC);
  end
{$ELSE}
If clock_getres(CLOCK_MONOTONIC_RAW,@Time) = 0 then
  begin
    fHighResolution := True;
    fFrequency := FC_NANOS_PER_SEC; // frequency is hardcoded for nanoseconds
    fResolution := (Int64(Time.tv_sec) * FC_NANOS_PER_SEC) + Time.tv_nsec;
  end
{$ENDIF}
else
  begin
    fHighResolution := False;
    fFrequency := FC_MILLIS_PER_SEC;
    fResolution := FC_NANOS_PER_MILLI;
  end;
end;

//------------------------------------------------------------------------------

procedure TFrameClock.Initialize;
begin
InitializeTime;
fFrameCounter := 0;
fCreationTicks := GetCurrentTicks;
fPrevFrameTicks := fCreationTicks;
fCurrFrameTicks := fCreationTicks;
FillChar(fFrameTime,SizeOf(TFCFrameTime),0);
end;

//------------------------------------------------------------------------------

procedure TFrameClock.Finalize;
begin
// nothing to do here
end;

{-------------------------------------------------------------------------------
    TFrameClock - public methods
-------------------------------------------------------------------------------}

constructor TFrameClock.Create;
begin
inherited Create(1);
Initialize;
end;

//------------------------------------------------------------------------------

destructor TFrameClock.Destroy;
begin
Finalize;
inherited;
end;

//------------------------------------------------------------------------------

Function TFrameClock.TickFrame: TFCFrameTime;
begin
Inc(fFrameCounter);
fPrevFrameTicks := fCurrFrameTicks;
fCurrFrameTicks := GetCurrentTicks;
fFrameTime.Ticks := GetTicksDiff(fPrevFrameTicks,fCurrFrameTicks);
FrameTimeFromTicks(fFrameTime);
Result := fFrameTime;
end;

//------------------------------------------------------------------------------

Function TFrameClock.TicksTime(Ticks: TFCTicks): TFCFrameTime;
begin
Result.Ticks := GetTicksDiff(Ticks,fCurrFrameTicks);
FrameTimeFromTicks(Result);
end;

//------------------------------------------------------------------------------

Function TFrameClock.LowIndex(List: Integer): Integer;
begin
case List of
  FC_LIST_IDX_TIMESTAMPS: Result := Low(fTimeStamps);
else
  raise EFCInvalidList.CreateFmt('TFrameClock.LowIndex: Invalid list (%d).',[List]);
end;
end;

//------------------------------------------------------------------------------

Function TFrameClock.HighIndex(List: Integer): Integer;
begin
case List of
  FC_LIST_IDX_TIMESTAMPS: Result := Pred(fTimeStampCount);
else
  raise EFCInvalidList.CreateFmt('TFrameClock.HighIndex: Invalid list (%d).',[List]);
end;
end;

//------------------------------------------------------------------------------

Function TFrameClock.TimeStampLowIndex: Integer;
begin
Result := LowIndex(FC_LIST_IDX_TIMESTAMPS);
end;

//------------------------------------------------------------------------------

Function TFrameClock.TimeStampHighIndex: Integer;
begin
Result := HighIndex(FC_LIST_IDX_TIMESTAMPS);
end;

//------------------------------------------------------------------------------

Function TFrameClock.TimeStampCheckIndex(Index: Integer): Boolean;
begin
Result := CheckIndex(FC_LIST_IDX_TIMESTAMPS,Index);
end;

//------------------------------------------------------------------------------

Function TFrameClock.TimeStampIndexOf(const Name: String): Integer;
var
  i:  Integer;
begin
Result := -1;
For i := TimeStampLowIndex to TimeStampHighIndex do
  If AnsiSameStr(fTimeStamps[i].Name,Name) then
    begin
      Result := i;
      Break{For i};
    end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TFrameClock.TimeStampIndexOf(Value: TFCTicks): Integer;
var
  i:  Integer;
begin
Result := -1;
For i := TimeStampLowIndex to TimeStampHighIndex do
  If fTimeStamps[i].Value = Value then
    begin
      Result := i;
      Break{For i};
    end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TFrameClock.TimeStampIndexOf(const Name: String; Value: TFCTicks): Integer;
var
  i:  Integer;
begin
Result := -1;
For i := TimeStampLowIndex to TimeStampHighIndex do
  If AnsiSameStr(fTimeStamps[i].Name,Name) and (fTimeStamps[i].Value = Value) then
    begin
      Result := i;
      Break{For i};
    end;
end;

//------------------------------------------------------------------------------

Function TFrameClock.TimeStampAdd(const Name: String; Value: TFCTicks; UserData: PtrInt = 0): Integer;
begin
Grow(FC_LIST_IDX_TIMESTAMPS);
Result := fTimeStampCount;
fTimeStamps[Result].Name := Name;
UniqueString(fTimeStamps[Result].Name);
fTimeStamps[Result].Value := Value;
fTimeStamps[Result].UserData := UserData;
Inc(fTimeStampCount);
end;

//------------------------------------------------------------------------------

Function TFrameClock.TimeStampAddCurrent(const Name: String; UserData: PtrInt = 0): Integer;
begin
Result := TimeStampAdd(Name,fCurrFrameTicks,UserData);
end;

//------------------------------------------------------------------------------

procedure TFrameClock.TimeStampInsert(Index: Integer; const Name: String; Value: TFCTicks; UserData: PtrInt = 0);
var
  i:  Integer;
begin
If TimeStampCheckIndex(Index) then
  begin
    Grow(FC_LIST_IDX_TIMESTAMPS);
    For i := TimeStampHighIndex downto Index do
      fTimeStamps[i + 1] := fTimeStamps[i];
    fTimeStamps[Index].Name := Name;
    UniqueString(fTimeStamps[Index].Name);
    fTimeStamps[Index].Value := Value;
    fTimeStamps[Index].UserData := UserData;
    Inc(fTimeStampCount);
  end
else TimeStampAdd(Name,Value,UserData);
end;

//------------------------------------------------------------------------------

Function TFrameClock.TimeStampRemove(const Name: String): Integer;
begin
Result := TimeStampIndexOf(Name);
If TimeStampCheckIndex(Result) then
  TimeStampDelete(Result);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TFrameClock.TimeStampRemove(Value: Int64): Integer;
begin
Result := TimeStampIndexOf(Value);
If TimeStampCheckIndex(Result) then
  TimeStampDelete(Result);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TFrameClock.TimeStampRemove(const Name: String; Value: Int64): Integer;
begin
Result := TimeStampIndexOf(Name,Value);
If TimeStampCheckIndex(Result) then
  TimeStampDelete(Result);
end;

//------------------------------------------------------------------------------

procedure TFrameClock.TimeStampDelete(Index: Integer);
var
  i:  Integer;
begin
If TimeStampCheckIndex(Index) then
  begin
    For i := Index to Pred(TimeStampHighIndex) do
      fTimeStamps[i] := fTimeStamps[i + 1];
    Dec(fTimeStampCount);
    Shrink(FC_LIST_IDX_TIMESTAMPS);
  end
else raise EFCIndexOutOfBounds.CreateFmt('TFrameClock.TimeStampDelete: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

procedure TFrameClock.TimeStampClear;
begin
SetLength(fTimeStamps,0);
fTimeStampCount := 0;
end;

//------------------------------------------------------------------------------

Function TFrameClock.TimeStampTime(Index: Integer): TFCFrameTime;
begin
If TimeStampCheckIndex(Index) then
  begin
    Result.Ticks := GetTicksDiff(fTimeStamps[Index].Value,fCurrFrameTicks);
    FrameTimeFromTicks(Result);
  end
else raise EFCIndexOutOfBounds.CreateFmt('TFrameClock.TimeStampTime: Index (%d) out of bounds.',[Index]);
end;

{===============================================================================
    Standalone functions - implementation
===============================================================================}

procedure ClockMeasuringStart(out Context: TClockMeasuringContext);
begin
Context := TClockMeasuringContext(TFrameClock.Create);
end;

//------------------------------------------------------------------------------

Function ClockMeasuringTick(var Context: TClockMeasuringContext; ReturnUnit: TClockMeasuringUnit = mruMilli): Int64;
begin
try
  TFrameClock(Context).TickFrame;
  case ReturnUnit of
    mruSecond:  Result := TFrameClock(Context).FrameTime.iSec;
    mruMilli:   Result := TFrameClock(Context).FrameTime.iMiS;
    mruMicro:   Result := TFrameClock(Context).FrameTime.iUiS;
  else
   {mruTick}
    Result := TFrameClock(Context).FrameTime.Ticks;
  end;
except
  Result := -1;
end;
end;

//------------------------------------------------------------------------------

Function ClockMeasuringEnd(var Context: TClockMeasuringContext; ReturnUnit: TClockMeasuringUnit = mruMilli): Int64;
begin
Result := ClockMeasuringTick(Context,ReturnUnit);
TFrameClock(Context).Free;
Context := nil;
end;

end.
