unit FrameClock;

{$IF Defined(WINDOWS) or Defined(MSWINDOWS)}
  {$DEFINE Windows}
{$ELSEIF Defined(LINUX) and Defined(FPC)}
  {$DEFINE Linux}
{$ELSE}
  {$MESSAGE FATAL 'Unsupported operating system.'}
{$IFEND}

{$IFDEF FPC}
  {$MODE Delphi}
  {$DEFINE FPC_DisableWarns}
  {$MACRO ON}
{$ENDIF}

interface

uses
  SysUtils,
  AuxTypes, AuxClasses;

type
  EFCException = class(Exception);

  EFCHighResolutionFail = class(EFCException);
  EFCSystemException    = class(EFCException);
  EFCInvalidList        = class(EFCException);
  EFCIndexOutOfBounds   = class(EFCException);

{===============================================================================
--------------------------------------------------------------------------------
                                   TFrameClock
--------------------------------------------------------------------------------
===============================================================================}
{
  TFrameClock class is intended to be used as a mean of measuring time between
  two points in time with high resolution. Note that high resolution does not
  necessarily mean high precission, especially on long time intervals.

  If high resolution clock is not awailable on the system, or it fails for
  whatever reason, it defaults to normal system timer (of which resolution is,
  in most cases, worse than one milliseconds). If the clock is running in high
  resolution mode or not can be checked in HighResolution property.
  Also, if you select to force high-res at creation and the HR timer cannot be
  used, the constructor raises an EFCHighResTmrFail exception.

  Space between the two measured points is called frame (hence frame clock).

  The distance is measured in ticks. Length of these ticks is implementation and
  system dependent, do not assume anything about them, it is just a number that
  has meaning only within the object that produced them. So do not pass these
  values between different instances of the frame clock.
}


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
    //- getters/setters ---
    Function GetCreationTime: TFCFrameTime; virtual;
    Function GetActualTime: TFCFrameTime; virtual;
    //- lists methods ---
    Function GetCapacity(List: Integer): Integer; override;
    procedure SetCapacity(List,Value: Integer); override;
    Function GetCount(List: Integer): Integer; override;
    procedure SetCount(List,Value: Integer); override;
    //- other protected methods ---
    Function GetCurrentTicks: TFCTicks; virtual;
    Function GetTicksDiff(A,B: TFCTicks): TFCTicks; virtual;
    procedure FrameTimeFromTicks(var FrameTime: TFCFrameTime); virtual;
    procedure InitializeTime; virtual;
    procedure Initialize; virtual;
    procedure Finalize; virtual;
  public
    constructor Create(ForceHighResolution: Boolean = False);
    destructor Destroy; override;
    Function TickFrame: TFCFrameTime; virtual;
    Function TicksTime(Ticks: TFCTicks): TFCFrameTime; virtual; // time between given ticks and current frame
    Function LowIndex(List: Integer): Integer; override;
    Function HighIndex(List: Integer): Integer; override;
    property HighResolution: Boolean read fHighResolution;
    property Frequency: Int64 read fFrequency;
    property Resolution: Int64 read fResolution;
    property FrameCounter: Int64 read fFrameCounter;
    property CreationTicks: TFCTicks read fCreationTicks;
    property PrevFrameTicks: TFCTicks read fPrevFrameTicks;
    property CurrFrameTicks: TFCTicks read fCurrFrameTicks;
    property CreationTime: TFCFrameTime read GetCreationTime;   // time from object creation to current frame
    property FrameTime: TFCFrameTime read fFrameTime;           // time from previous frame to current frame
    property ActualTime: TFCFrameTime read GetActualTime;       // time from current frame to actual time (moment the property is accessed)
  end;

{===============================================================================
--------------------------------------------------------------------------------
                                  TFrameClockEx
--------------------------------------------------------------------------------
===============================================================================}

// types and constants for lists...
type
  TFCTimeStamp = record
    Name:     String;
    Value:    TFCTicks; // stores tisck at which the time stamp was made
    UserData: PtrInt;
  end;
  PFCTimeStamp = ^TFCTimeStamp;

  TFCAccumulator = record
    Name:     String;
    Value:    TFCTicks; // stores number of ticks accumulated (ie. a length of time)
    UserData: PtrInt;
  end;
  PFCAccumulator = ^TFCAccumulator;

const
  FCE_LIST_IDX_TIMESTAMPS   = 0;
  FCE_LIST_IDX_ACCUMULATORS = 1;

{===============================================================================
    TFrameClockEx - class declaration
===============================================================================}

type
  TFrameClockEx = class(TFrameClock)
  protected
    fTimeStamps:        array of TFCTimeStamp;
    fTimeStampCount:    Integer;
    fAccumulators:      array of TFCAccumulator;
    fAccumulatorCount:  Integer;
    //- lists getters/setters ---
    Function GetTimeStamp(Index: Integer): TFCTimeStamp; virtual;
    procedure SetTimeStamp(Index: Integer; Value: TFCTimeStamp); virtual;
    Function GetTimeStampPtr(Index: Integer): PFCTimeStamp; virtual;
    Function GetAccumulator(Index: Integer): TFCAccumulator; virtual;
    procedure SetAccumulator(Index: Integer; Value: TFCAccumulator); virtual;
    Function GetAccumulatorPtr(Index: Integer): PFCAccumulator; virtual;
    //- inherited list methods ---
    Function GetCapacity(List: Integer): Integer; override;
    procedure SetCapacity(List,Value: Integer); override;
    Function GetCount(List: Integer): Integer; override;
    procedure SetCount(List,Value: Integer); override;
    //- other methods ---
    procedure Initialize; override;
    procedure Finalize; override;
  public
    constructor Create;
    Function LowIndex(List: Integer): Integer; override;
    Function HighIndex(List: Integer): Integer; override;
    //- timestamps list ---
    Function TimeStampLowIndex: Integer; virtual;
    Function TimeStampHighIndex: Integer; virtual;
    Function TimeStampCheckIndex(Index: Integer): Boolean; virtual;
    Function TimeStampIndexOf(const Name: String): Integer; overload; virtual;
    Function TimeStampIndexOf(Value: TFCTicks): Integer; overload; virtual;
    Function TimeStampIndexOf(const Name: String; Value: TFCTicks): Integer; overload; virtual;
    Function TimeStampAdd(const Name: String; Value: TFCTicks; UserData: PtrInt = 0): Integer; virtual;
    Function TimeStampAddCurrent(const Name: String; UserData: PtrInt = 0): Integer; virtual; // adds current frame ticks as a new timestamp
    procedure TimeStampInsert(Index: Integer; const Name: String; Value: TFCTicks; UserData: PtrInt = 0); virtual;
    Function TimeStampRemove(const Name: String): Integer; overload; virtual;
    Function TimeStampRemove(Value: TFCTicks): Integer; overload; virtual;
    Function TimeStampRemove(const Name: String; Value: TFCTicks): Integer; overload; virtual;
    procedure TimeStampDelete(Index: Integer); virtual;
    procedure TimeStampClear; virtual;
    Function TimeStampTime(Index: Integer): TFCFrameTime; overload; virtual;    // time between selected timestamp and current frame
    Function TimeStampTime(const Name: String): TFCFrameTime; overload; virtual;
    //- accumulators list ---
    Function AccumulatorLowIndex: Integer; virtual;
    Function AccumulatorHighIndex: Integer; virtual;
    Function AccumulatorCheckIndex(Index: Integer): Boolean; virtual;
    Function AccumulatorIndexOf(const Name: String): Integer; overload; virtual;
    Function AccumulatorIndexOf(Value: TFCTicks): Integer; overload; virtual;
    Function AccumulatorIndexOf(const Name: String; Value: TFCTicks): Integer; overload; virtual;
    Function AccumulatorAdd(const Name: String; InitialValue: TFCTicks = 0; UserData: PtrInt = 0): Integer; virtual;
    procedure AccumulatorInsert(Index: Integer; const Name: String; InitialValue: TFCTicks = 0; UserData: PtrInt = 0); virtual;
    Function AccumulatorRemove(const Name: String): Integer; overload; virtual;
    Function AccumulatorRemove(Value: TFCTicks): Integer; overload; virtual;
    Function AccumulatorRemove(const Name: String; Value: TFCTicks): Integer; overload; virtual;
    procedure AccumulatorDelete(Index: Integer); virtual;
    procedure AccumulatorClear; virtual;
    procedure AccumulatorReset(Index: Integer); virtual;
    Function AccumulatorAccumulate(Index: Integer; Delta: TFCTicks): TFCFrameTime; overload; virtual;
    Function AccumulatorAccumulate(Index: Integer): TFCFrameTime; overload; virtual;
    Function AccumulatorAccumulate(const Name: String; Delta: TFCTicks): TFCFrameTime; overload; virtual;
    Function AccumulatorAccumulate(const Name: String): TFCFrameTime; overload; virtual;
    procedure AccumulatorAccumulateAll(Delta: TFCTicks); overload; virtual;
    procedure AccumulatorAccumulateAll; overload; virtual;
    Function AccumulatorTime(Index: Integer): TFCFrameTime; overload; virtual;
    Function AccumulatorTime(const Name: String): TFCFrameTime; overload; virtual;
    //- timestamp properties ---
    property TimeStampCount: Integer index FCE_LIST_IDX_TIMESTAMPS read GetCount write SetCount;
    property TimeStampCapacity: Integer index FCE_LIST_IDX_TIMESTAMPS read GetCapacity write SetCapacity;
    property TimeStamps[Index: Integer]: TFCTimeStamp read GetTimeStamp write SetTimeStamp;
    property TimeStampPtrs[Index: Integer]: PFCTimeStamp read GetTimeStampPtr;
    //- accumulator properties ---
    property AccumulatorCount: Integer index FCE_LIST_IDX_ACCUMULATORS read GetCount write SetCount;
    property AccumulatorCapacity: Integer index FCE_LIST_IDX_ACCUMULATORS read GetCapacity write SetCapacity;
    property Accumulators[Index: Integer]: TFCAccumulator read GetAccumulator write SetAccumulator;
    property AccumulatorPtrs[Index: Integer]: PFCAccumulator read GetAccumulatorPtr;
  end;

{===============================================================================
    Standalone functions - declaration
===============================================================================}

type
  TClockMeasureContext = type Pointer;

  TClockMeasureUnit = (mruTick,mruSecond,mruMilli,mruMicro);

procedure ClockMeasureStart(out Context: TClockMeasureContext);
Function ClockMeasureTick(var Context: TClockMeasureContext; ReturnUnit: TClockMeasureUnit = mruMilli): Int64;
Function ClockMeasureEnd(var Context: TClockMeasureContext; ReturnUnit: TClockMeasureUnit = mruMilli): Int64;

implementation

uses
{$IFDEF Windows}Windows{$ELSE}baseunix, linux{$ENDIF};

{$IFDEF FPC_DisableWarns}
  {$DEFINE FPCDWM}
  {$DEFINE W5024:={$WARN 5024 OFF}} // Parameter "$1" not used
{$ENDIF}

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
Result.Ticks := GetTicksDiff(fCurrFrameTicks,GetCurrentTicks);
FrameTimeFromTicks(Result);
end;

//------------------------------------------------------------------------------

Function TFrameClock.GetCapacity(List: Integer): Integer;
begin
{$IFDEF FPC}Result := 0;{$ENDIF}
raise EFCInvalidList.CreateFmt('TFrameClock.GetCapacity: Invalid list (%d).',[List]);
end;

//------------------------------------------------------------------------------

{$IFDEF FPCDWM}{$PUSH}W5024{$ENDIF}
procedure TFrameClock.SetCapacity(List,Value: Integer);
begin
raise EFCInvalidList.CreateFmt('TFrameClock.SetCapacity: Invalid list (%d).',[List]);
end;
{$IFDEF FPCDWM}{$POP}{$ENDIF}

//------------------------------------------------------------------------------

Function TFrameClock.GetCount(List: Integer): Integer;
begin
{$IFDEF FPC}Result := 0;{$ENDIF}
raise EFCInvalidList.CreateFmt('TFrameClock.GetCount: Invalid list (%d).',[List]);
end;

//------------------------------------------------------------------------------

{$IFDEF FPCDWM}{$PUSH}W5024{$ENDIF}
procedure TFrameClock.SetCount(List,Value: Integer);
begin
raise EFCInvalidList.CreateFmt('TFrameClock.SetCount: Invalid list (%d).',[List]);
end;
{$IFDEF FPCDWM}{$POP}{$ENDIF}

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
var
  Temp: Extended;
begin
Temp := FrameTime.Ticks / fFrequency;
FrameTime.Sec := Temp;
FrameTime.MiS := Temp * FC_MILLIS_PER_SEC;
FrameTime.UiS := Temp * FC_MICROS_PER_SEC;
FrameTime.iSec := Trunc(Temp);
FrameTime.iMiS := Trunc(Temp * FC_MILLIS_PER_SEC);
FrameTime.iUiS := Trunc(Temp * FC_MICROS_PER_SEC);
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

constructor TFrameClock.Create(ForceHighResolution: Boolean = False);
begin
inherited Create(0);
Initialize;
If ForceHighResolution and not fHighResolution then
 raise EFCHighResolutionFail.Create('TFrameClock.Create: Failed to obtain high resolution timer.');
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
{$IFDEF FPC}Result := 0;{$ENDIF}
raise EFCInvalidList.CreateFmt('TFrameClock.LowIndex: Invalid list (%d).',[List]);
end;

//------------------------------------------------------------------------------

Function TFrameClock.HighIndex(List: Integer): Integer;
begin
{$IFDEF FPC}Result := -1;{$ENDIF}
raise EFCInvalidList.CreateFmt('TFrameClock.HighIndex: Invalid list (%d).',[List]);
end;

{===============================================================================
--------------------------------------------------------------------------------
                                  TFrameClockEx
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TFrameClockEx - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    TFrameClockEx - protected methods
-------------------------------------------------------------------------------}

Function TFrameClockEx.GetTimeStamp(Index: Integer): TFCTimeStamp;
begin
If TimeStampCheckIndex(Index) then
  Result := fTimeStamps[Index]
else
  raise EFCIndexOutOfBounds.CreateFmt('TFrameClockEx.GetTimeStamp: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

procedure TFrameClockEx.SetTimeStamp(Index: Integer; Value: TFCTimeStamp);
begin
If TimeStampCheckIndex(Index) then
  fTimeStamps[Index] := Value
else
  raise EFCIndexOutOfBounds.CreateFmt('TFrameClockEx.SetTimeStamp: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.GetTimeStampPtr(Index: Integer): PFCTimeStamp;
begin
If TimeStampCheckIndex(Index) then
  Result := Addr(fTimeStamps[Index])
else
  raise EFCIndexOutOfBounds.CreateFmt('TFrameClockEx.GetTimeStampPtr: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.GetAccumulator(Index: Integer): TFCAccumulator;
begin
If AccumulatorCheckIndex(Index) then
  Result := fAccumulators[Index]
else
  raise EFCIndexOutOfBounds.CreateFmt('TFrameClockEx.GetAccumulator: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

procedure TFrameClockEx.SetAccumulator(Index: Integer; Value: TFCAccumulator);
begin
If AccumulatorCheckIndex(Index) then
  fAccumulators[Index] := Value
else
  raise EFCIndexOutOfBounds.CreateFmt('TFrameClockEx.SetAccumulator: Index (%d) out of bounds.',[Index]);
end;
 
//------------------------------------------------------------------------------

Function TFrameClockEx.GetAccumulatorPtr(Index: Integer): PFCAccumulator;
begin
If AccumulatorCheckIndex(Index) then
  Result := Addr(fAccumulators[Index])
else
  raise EFCIndexOutOfBounds.CreateFmt('TFrameClockEx.GetAccumulatorPtr: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.GetCapacity(List: Integer): Integer;
begin
case List of
  FCE_LIST_IDX_TIMESTAMPS:    Result := Length(fTimeStamps);
  FCE_LIST_IDX_ACCUMULATORS:  Result := Length(fAccumulators);
else
  Result := inherited GetCapacity(List);
end;
end;

//------------------------------------------------------------------------------

procedure TFrameClockEx.SetCapacity(List,Value: Integer);
begin
case List of
  FCE_LIST_IDX_TIMESTAMPS:    begin
                                If Value < fTimeStampCount then
                                  fTimeStampCount := Value;
                                SetLength(fTimeStamps,Value);
                              end;
  FCE_LIST_IDX_ACCUMULATORS:  begin
                                If Value < fAccumulatorCount then
                                  fAccumulatorCount := Value;
                                SetLength(fAccumulators,Value);
                              end;
else
  inherited SetCapacity(List,Value);
end;
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.GetCount(List: Integer): Integer;
begin
case List of
  FCE_LIST_IDX_TIMESTAMPS:    Result := fTimeStampCount;
  FCE_LIST_IDX_ACCUMULATORS:  Result := fAccumulatorCount;
else
  Result := inherited GetCount(List);
end;
end;

//------------------------------------------------------------------------------

procedure TFrameClockEx.SetCount(List,Value: Integer);
begin
case List of
  FCE_LIST_IDX_TIMESTAMPS:;   // do nothing
  FCE_LIST_IDX_ACCUMULATORS:; // do nothing
else
  inherited SetCount(List,Value);
end;
end;

//------------------------------------------------------------------------------

procedure TFrameClockEx.Initialize;
begin
inherited;
SetLength(fTimeStamps,0);
fTimeStampCount := 0;
SetLength(fAccumulators,0);
fAccumulatorCount := 0;
end;

//------------------------------------------------------------------------------

procedure TFrameClockEx.Finalize;
begin
TimeStampClear;
AccumulatorClear;
inherited;
end;

{-------------------------------------------------------------------------------
    TFrameClockEx - public methods
-------------------------------------------------------------------------------}

constructor TFrameClockEx.Create;
begin
inherited Create;
ListCount := ListCount + 2;
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.LowIndex(List: Integer): Integer;
begin
case List of
  FCE_LIST_IDX_TIMESTAMPS:    Result := Low(fTimeStamps);
  FCE_LIST_IDX_ACCUMULATORS:  Result := Low(fAccumulators);
else
  Result := inherited LowIndex(List);
end;
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.HighIndex(List: Integer): Integer;
begin
case List of
  FCE_LIST_IDX_TIMESTAMPS:    Result := Pred(fTimeStampCount);
  FCE_LIST_IDX_ACCUMULATORS:  Result := Pred(fAccumulatorCount);
else
  Result := inherited HighIndex(List);
end;
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.TimeStampLowIndex: Integer;
begin
Result := LowIndex(FCE_LIST_IDX_TIMESTAMPS);
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.TimeStampHighIndex: Integer;
begin
Result := HighIndex(FCE_LIST_IDX_TIMESTAMPS);
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.TimeStampCheckIndex(Index: Integer): Boolean;
begin
Result := CheckIndex(FCE_LIST_IDX_TIMESTAMPS,Index);
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.TimeStampIndexOf(const Name: String): Integer;
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

Function TFrameClockEx.TimeStampIndexOf(Value: TFCTicks): Integer;
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

Function TFrameClockEx.TimeStampIndexOf(const Name: String; Value: TFCTicks): Integer;
var
  i:  Integer;
begin
Result := -1;
For i := TimeStampLowIndex to TimeStampHighIndex do
  If (fTimeStamps[i].Value = Value) and AnsiSameStr(fTimeStamps[i].Name,Name) then
    begin
      Result := i;
      Break{For i};
    end;
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.TimeStampAdd(const Name: String; Value: TFCTicks; UserData: PtrInt = 0): Integer;
begin
Grow(FCE_LIST_IDX_TIMESTAMPS);
Result := fTimeStampCount;
fTimeStamps[Result].Name := Name;
UniqueString(fTimeStamps[Result].Name);
fTimeStamps[Result].Value := Value;
fTimeStamps[Result].UserData := UserData;
Inc(fTimeStampCount);
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.TimeStampAddCurrent(const Name: String; UserData: PtrInt = 0): Integer;
begin
Result := TimeStampAdd(Name,fCurrFrameTicks,UserData);
end;

//------------------------------------------------------------------------------

procedure TFrameClockEx.TimeStampInsert(Index: Integer; const Name: String; Value: TFCTicks; UserData: PtrInt = 0);
var
  i:  Integer;
begin
If TimeStampCheckIndex(Index) then
  begin
    Grow(FCE_LIST_IDX_TIMESTAMPS);
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

Function TFrameClockEx.TimeStampRemove(const Name: String): Integer;
begin
Result := TimeStampIndexOf(Name);
If TimeStampCheckIndex(Result) then
  TimeStampDelete(Result);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TFrameClockEx.TimeStampRemove(Value: TFCTicks): Integer;
begin
Result := TimeStampIndexOf(Value);
If TimeStampCheckIndex(Result) then
  TimeStampDelete(Result);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TFrameClockEx.TimeStampRemove(const Name: String; Value: TFCTicks): Integer;
begin
Result := TimeStampIndexOf(Name,Value);
If TimeStampCheckIndex(Result) then
  TimeStampDelete(Result);
end;

//------------------------------------------------------------------------------

procedure TFrameClockEx.TimeStampDelete(Index: Integer);
var
  i:  Integer;
begin
If TimeStampCheckIndex(Index) then
  begin
    For i := Index to Pred(TimeStampHighIndex) do
      fTimeStamps[i] := fTimeStamps[i + 1];
    Dec(fTimeStampCount);
    Shrink(FCE_LIST_IDX_TIMESTAMPS);
  end
else raise EFCIndexOutOfBounds.CreateFmt('TFrameClockEx.TimeStampDelete: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

procedure TFrameClockEx.TimeStampClear;
begin
SetLength(fTimeStamps,0);
fTimeStampCount := 0;
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.TimeStampTime(Index: Integer): TFCFrameTime;
begin
If TimeStampCheckIndex(Index) then
  begin
    Result.Ticks := GetTicksDiff(fTimeStamps[Index].Value,fCurrFrameTicks);
    FrameTimeFromTicks(Result);
  end
else raise EFCIndexOutOfBounds.CreateFmt('TFrameClockEx.TimeStampTime: Index (%d) out of bounds.',[Index]);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TFrameClockEx.TimeStampTime(const Name: String): TFCFrameTime;
var
  Index:  Integer;
begin
Index := TimeStampIndexOf(Name);
If TimeStampCheckIndex(Index) then
  Result := TimeStampTime(Index)
else
  FillChar(Addr(Result)^,SizeOf(TFCFrameTime),0);
{
  Addr(Result)^ is there as a workaround for nonsensical warning in FPC about
  result being not set.
}
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.AccumulatorLowIndex: Integer;
begin
Result := LowIndex(FCE_LIST_IDX_ACCUMULATORS);
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.AccumulatorHighIndex: Integer;
begin
Result := HighIndex(FCE_LIST_IDX_ACCUMULATORS);
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.AccumulatorCheckIndex(Index: Integer): Boolean;
begin
Result := CheckIndex(FCE_LIST_IDX_ACCUMULATORS,Index);
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.AccumulatorIndexOf(const Name: String): Integer;
var
  i:  Integer;
begin
Result := -1;
For i := AccumulatorLowIndex to AccumulatorHighIndex do
  If AnsiSameStr(fAccumulators[i].Name,Name) then
    begin
      Result := i;
      Break{For i};
    end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TFrameClockEx.AccumulatorIndexOf(Value: TFCTicks): Integer;
var
  i:  Integer;
begin
Result := -1;
For i := AccumulatorLowIndex to AccumulatorHighIndex do
  If fAccumulators[i].Value = Value then
    begin
      Result := i;
      Break{For i};
    end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TFrameClockEx.AccumulatorIndexOf(const Name: String; Value: TFCTicks): Integer;
var
  i:  Integer;
begin
Result := -1;
For i := AccumulatorLowIndex to AccumulatorHighIndex do
  If (fAccumulators[i].Value = Value) and AnsiSameStr(fAccumulators[i].Name,Name) then
    begin
      Result := i;
      Break{For i};
    end;
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.AccumulatorAdd(const Name: String; InitialValue: TFCTicks = 0; UserData: PtrInt = 0): Integer;
begin
Grow(FCE_LIST_IDX_ACCUMULATORS);
Result := fAccumulatorCount;
fAccumulators[Result].Name := Name;
UniqueString(fAccumulators[Result].Name);
fAccumulators[Result].Value := InitialValue;
fAccumulators[Result].UserData := UserData;
Inc(fAccumulatorCount);
end;

//------------------------------------------------------------------------------

procedure TFrameClockEx.AccumulatorInsert(Index: Integer; const Name: String; InitialValue: TFCTicks = 0; UserData: PtrInt = 0);
var
  i:  Integer;
begin
If AccumulatorCheckIndex(Index) then
  begin
    Grow(FCE_LIST_IDX_ACCUMULATORS);
    For i := AccumulatorHighIndex downto Index do
      fAccumulators[i + 1] := fAccumulators[i];
    fAccumulators[Index].Name := Name;
    UniqueString(fAccumulators[Index].Name);
    fAccumulators[Index].Value := InitialValue;
    fAccumulators[Index].UserData := UserData;
    Inc(fAccumulatorCount);
  end
else AccumulatorAdd(Name,InitialValue,UserData);
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.AccumulatorRemove(const Name: String): Integer;
begin
Result := AccumulatorIndexOf(Name);
If AccumulatorCheckIndex(Result) then
  AccumulatorDelete(Result);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TFrameClockEx.AccumulatorRemove(Value: TFCTicks): Integer;
begin
Result := AccumulatorIndexOf(Value);
If AccumulatorCheckIndex(Result) then
  AccumulatorDelete(Result);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TFrameClockEx.AccumulatorRemove(const Name: String; Value: TFCTicks): Integer;
begin
Result := AccumulatorIndexOf(Name,Value);
If AccumulatorCheckIndex(Result) then
  AccumulatorDelete(Result);
end;

//------------------------------------------------------------------------------

procedure TFrameClockEx.AccumulatorDelete(Index: Integer);
var
  i:  Integer;
begin
If AccumulatorCheckIndex(Index) then
  begin
    For i := Index to Pred(AccumulatorHighIndex) do
      fAccumulators[i] := fAccumulators[i + 1];
    Dec(fAccumulatorCount);
    Shrink(FCE_LIST_IDX_ACCUMULATORS);
  end
else raise EFCIndexOutOfBounds.CreateFmt('TFrameClockEx.AccumulatorDelete: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

procedure TFrameClockEx.AccumulatorClear;
begin
SetLength(fAccumulators,0);
fAccumulatorCount := 0;
end;

//------------------------------------------------------------------------------

procedure TFrameClockEx.AccumulatorReset(Index: Integer);
begin
If AccumulatorCheckIndex(Index) then
  fAccumulators[Index].Value := 0
else
  raise EFCIndexOutOfBounds.CreateFmt('TFrameClockEx.AccumulatorReset: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.AccumulatorAccumulate(Index: Integer; Delta: TFCTicks): TFCFrameTime;
begin
If AccumulatorCheckIndex(Index) then
  begin
    fAccumulators[Index].Value := fAccumulators[Index].Value + Delta;
    Result.Ticks := fAccumulators[Index].Value;
    FrameTimeFromTicks(Result);
  end
else raise EFCIndexOutOfBounds.CreateFmt('TFrameClockEx.AccumulatorAccumulate: Index (%d) out of bounds.',[Index]);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TFrameClockEx.AccumulatorAccumulate(Index: Integer): TFCFrameTime;
begin
Result := AccumulatorAccumulate(Index,fFrameTime.Ticks);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TFrameClockEx.AccumulatorAccumulate(const Name: String; Delta: TFCTicks): TFCFrameTime;
var
  Index:  Integer;
begin
Index := AccumulatorIndexOf(Name);
If AccumulatorCheckIndex(Index) then
  Result := AccumulatorAccumulate(Index,Delta)
else
  FillChar(Result,SizeOf(TFCFrameTime),0);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TFrameClockEx.AccumulatorAccumulate(const Name: String): TFCFrameTime;
begin
Result := AccumulatorAccumulate(Name,fFrameTime.Ticks);
end;

//------------------------------------------------------------------------------

procedure TFrameClockEx.AccumulatorAccumulateAll(Delta: TFCTicks);
var
  i:  Integer;
begin
For i := AccumulatorLowIndex to AccumulatorHighIndex do
  fAccumulators[i].Value := fAccumulators[i].Value + Delta; 
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TFrameClockEx.AccumulatorAccumulateAll;
begin
AccumulatorAccumulateAll(fFrameTime.Ticks);
end;

//------------------------------------------------------------------------------

Function TFrameClockEx.AccumulatorTime(Index: Integer): TFCFrameTime;
begin
If AccumulatorCheckIndex(Index) then
  begin
    Result.Ticks := fAccumulators[Index].Value;
    FrameTimeFromTicks(Result);
  end
else raise EFCIndexOutOfBounds.CreateFmt('TFrameClockEx.AccumulatorTime: Index (%d) out of bounds.',[Index]);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TFrameClockEx.AccumulatorTime(const Name: String): TFCFrameTime;
var
  Index:  Integer;
begin
Index := AccumulatorIndexOf(Name);
If AccumulatorCheckIndex(Index) then
  Result := AccumulatorTime(Index)
else
  FillChar(Result,SizeOf(TFCFrameTime),0);
end;

{===============================================================================
    Standalone functions - implementation
===============================================================================}

procedure ClockMeasureStart(out Context: TClockMeasureContext);
begin
Context := TClockMeasureContext(TFrameClock.Create);
end;

//------------------------------------------------------------------------------

Function ClockMeasureTick(var Context: TClockMeasureContext; ReturnUnit: TClockMeasureUnit = mruMilli): Int64;
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

Function ClockMeasureEnd(var Context: TClockMeasureContext; ReturnUnit: TClockMeasureUnit = mruMilli): Int64;
begin
try
  Result := ClockMeasureTick(Context,ReturnUnit);
  TFrameClock(Context).Free;
  Context := nil;
except
  Result := -1;
end;
end;

end.
