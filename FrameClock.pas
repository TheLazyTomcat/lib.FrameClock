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
  AuxClasses;

type
  EFCException = class(Exception);

  EFCSystemException = class(EFCException);

  TFCFrameTicks = Int64;

  TFCFrameTime = record
    Ticks:  TFCFrameTicks;
    Sec:    Double;   // seconds
    MiS:    Double;   // milliseconds
    UiS:    Double;   // microseconds
    iSec:   Int64;    // integral seconds
    iMiS:   Int64;    // integral milliseconds
    iUiS:   Int64;    // integral microseconds
  end;

  TFrameClock = class(TCustomObject)
  protected
    fHighResolution:  Boolean;
    fFrequency:       Int64;          // [Hz]
    fResolution:      Int64;          // [ns]
    fFrameCounter:    Int64;          // number of measured frames
    fCreationTicks:   TFCFrameTicks;
    fPrevFrameTicks:  TFCFrameTicks;
    fCurrFrameTicks:  TFCFrameTicks;
    fFrameTime:       TFCFrameTime;
    fStamps:          array of TFCFrameTicks;
    fStampCount:      Integer;
    Function GetCreationTime: TFCFrameTime; virtual;
    Function GetActualTime: TFCFrameTime; virtual;
    Function GetCurrentTicks: TFCFrameTicks; virtual;
    Function GetTicksDiff(A,B: TFCFrameTicks): TFCFrameTicks; virtual;
    procedure FrameTimeFromTicks(var FrameTime: TFCFrameTime); virtual;
    procedure InitializeTime; virtual;
    procedure Initialize; virtual;
    procedure Finalize; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    Function TickFrame: TFCFrameTime; virtual; 
    property HighResolution: Boolean read fHighResolution;
    property Frequency: Int64 read fFrequency;
    property Resolution: Int64 read fResolution;
    property FrameCounter: Int64 read fFrameCounter;
    property CreationTicks: TFCFrameTicks read fCreationTicks;
    property PrevFrameTicks: TFCFrameTicks read fPrevFrameTicks;
    property CurrFrameTicks: TFCFrameTicks read fCurrFrameTicks;
  {
    CreationTime - time from object creation to current frame end.
  }
    property CreationTime: TFCFrameTime read GetCreationTime;
  {
    FrameTime - time from previous frame end to current frame end.
  }
    property FrameTime: TFCFrameTime read fFrameTime;
  {
    ActualTime - time from previous frame end to actual time (moment the
                 property is accessed).
  }
    property ActualTime: TFCFrameTime read GetActualTime;
  end;

//==============================================================================
// standalone functions

type
  TClockMeasuringContext = type Pointer;

  TClockMeasuringUnit = (mruTick,mruSecond,mruMilli,mruMicro);

procedure ClockMeasuringStart(out Context: TClockMeasuringContext);
Function ClockMeasuringTick(var Context: TClockMeasuringContext; ReturnUnit: TClockMeasuringUnit = mruMilli): Int64;
Function ClockMeasuringEnd(var Context: TClockMeasuringContext; ReturnUnit: TClockMeasuringUnit = mruMilli): Int64;

implementation

uses
{$IFDEF Windows}Windows{$ELSE}baseunix, linux{$ENDIF};

const
  FC_MILLIS_PER_SEC = 1000;         // millisecodns per second
  FC_MICROS_PER_SEC = 1000000;      // microsecodns per second
  FC_NANOS_PER_SEC  = 1000000000;   // nanoseconds per second

  FC_NANOS_PER_MILLI = 1000000;     // nanoseconds per millisecond
  FC_MILLIS_PER_DAY  = 86400000;    // milliseconds per day

//==============================================================================

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

Function TFrameClock.GetCurrentTicks: TFCFrameTicks;
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
else Result := TFCFrameTicks(Trunc(Now * FC_MILLIS_PER_DAY));
end;

//------------------------------------------------------------------------------

Function TFrameClock.GetTicksDiff(A,B: TFCFrameTicks): TFCFrameTicks;
begin
If B > A then
  Result := B - A
else
  Result := High(TFCFrameTicks) - A + B + 1{overflow tick};
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

//==============================================================================

constructor TFrameClock.Create;
begin
inherited;
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

//==============================================================================

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
    mruSecond:  Result := Int64(Trunc(TFrameClock(Context).FrameTime.Sec));
    mruMilli:   Result := TFrameClock(Context).FrameTime.iMiS;
    mruMicro:   Result := TFrameClock(Context).FrameTime.iUiS;
  else
   {mruTick}
    Result := Int64(TFrameClock(Context).FrameTime.Ticks);
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
