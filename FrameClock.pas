unit FrameClock;

interface

uses
  SysUtils,
  AuxTypes, AuxClasses;

type
  EFCException = class(Exception);

  EFCSystemException = class(EFCException);

  TFCFrameTicks = Int64;  // system-dependent

  TFCFrameTime = record
    Ticks:  TFCFrameTicks;
    Sec:    Double;   // seconds
    MiS:    Double;   // milliseconds
    UiS:    Double;   // microseconds
    iMiS:   Int64;    // integral milliseconds
    iUiS:   Int64;    // integral microseconds
  end;

  TFrameClock = class(TCustomObject)
  protected
    fHighResolution:  Boolean;
    fFrequency:       Int64;          // [Hz]
    fResolution:      Int64;          // [ns]
    fFrameCounter:    UInt64;         // number of measured frames
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
    property FrameCounter: UInt64 read fFrameCounter;
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

implementation

uses
  Windows;

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
begin
If fHighResolution then
  begin
    If QueryPerformanceCounter(Result) then
      Result := Result and $7FFFFFFFFFFFFFFF  // mask out sign bit
    else
      raise EFCSystemException.CreateFmt('TFrameClock.GetCurrentTicks: System error 0x%.8x.',[GetLastError]);
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
FrameTime.iMiS := Trunc(FrameTime.MiS);
FrameTime.iUiS := Trunc(FrameTime.UiS);
end;

//------------------------------------------------------------------------------

procedure TFrameClock.InitializeTime;
begin
If QueryPerformanceFrequency(fFrequency) then
  begin
    fHighResolution := True;
    fFrequency := fFrequency and $7FFFFFFFFFFFFFFF; // mask out sign bit
    fResolution := Trunc((1 / fFrequency) * FC_NANOS_PER_SEC);
  end
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

end.
