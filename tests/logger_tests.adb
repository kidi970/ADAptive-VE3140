with Ada.Text_IO; use Ada.Text_IO;
with Ada.Real_Time; use Ada.Real_Time;
with Adaptive_Log_Core;
procedure Logger_Tests is
   Checks : Natural := 0;
   Now : Time := Time_First;
   Step : Time_Span := Time_Span_Zero;
   Is_Ready, Clock_Fails, Write_Fails : Boolean := True;
   Output : String (1 .. 1_000) := (others => '?');
   Used, Reads : Natural := 0;
   function Test_Clock return Time is
      Result : constant Time := Now;
   begin
      if Clock_Fails then raise Program_Error; end if;
      Now := Now + Step;
      return Result;
   end Test_Clock;
   function Ready return Boolean is
   begin
      Reads := Reads + 1;
      return Is_Ready;
   end Ready;
   procedure Write_Byte (C : Character) is
   begin
      if Write_Fails then raise Program_Error; end if;
      Used := Used + 1; Output (Used) := C;
   end Write_Byte;
   package Good is new Adaptive_Log_Core (Test_Clock, Ready, Write_Byte);
   package Timed is new Adaptive_Log_Core (Test_Clock, Ready, Write_Byte);
   package Stalled is new Adaptive_Log_Core
     (Test_Clock, Ready, Write_Byte, Poll_Limit => 7);
   package Clock_Error is new Adaptive_Log_Core (Test_Clock, Ready, Write_Byte);
   package Write_Error is new Adaptive_Log_Core (Test_Clock, Ready, Write_Byte);
   package Backwards is new Adaptive_Log_Core (Test_Clock, Ready, Write_Byte);
   package Slow_Line is new Adaptive_Log_Core (Test_Clock, Ready, Write_Byte);
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if not Condition then raise Program_Error with Name; end if;
      Checks := Checks + 1;
   end Check;
   procedure Reset is
   begin
      Used := 0; Reads := 0; Is_Ready := True;
      Clock_Fails := False; Write_Fails := False;
      Now := Time_First + Seconds (10); Step := Time_Span_Zero;
   end Reset;
begin
   Check (Reads = 0 and Used = 0, "elaboration never calls transport");
   Reset;
   Check (Good.Try_Line (""), "empty line");
   Check (Used = 2 and Output (1 .. 2) = ASCII.CR & ASCII.LF, "empty CRLF");
   Reset;
   Check (Good.Try_Line ("abc"), "normal line");
   Check (Used = 5 and Output (1 .. 5) = "abc" & ASCII.CR & ASCII.LF, "text");
   Reset;
   Check (Good.Try_Line ((10 .. 169 => 'X')), "exact capacity arbitrary index");
   Check (Used = 162 and not Good.Truncated_Last_Line, "capacity and delimiter");
   Reset;
   Check (Good.Try_Line ((1 .. 10_000 => 'Y')), "bounded oversized message");
   Check (Used = 162 and Good.Truncated_Last_Line, "oversize length");
   Check (Output (158 .. 160) = "...", "explicit truncation marker");
   Reset;
   Check (Good.Try_Line ("again") and not Good.Truncated_Last_Line,
          "truncation status resets on next line");
   Reset;
   Check (Good.Try_Line ("a" & ASCII.LF & ASCII.NUL & ASCII.CR), "control text");
   Check (Output (1 .. 4) = "a???", "no forged records");
   Reset; Is_Ready := False; Step := Milliseconds (10);
   Check (not Timed.Try_Line ("timeout") and Timed.Failed, "clock deadline");
   Check (Used = 0 and Reads = 2, "deadline before byte");
   Is_Ready := True;
   Check (not Timed.Try_Line ("retry") and Used = 0, "sticky circuit breaker");
   Reset; Is_Ready := False;
   Check (not Stalled.Try_Line ("frozen") and Reads = 7, "frozen clock finite polls");
   Check (Stalled.Failed and Used = 0, "frozen clock disables output");
   Reset; Clock_Fails := True;
   Check (not Clock_Error.Try_Line ("clock") and Clock_Error.Failed, "clock exception contained");
   Reset; Write_Fails := True;
   Check (not Write_Error.Try_Line ("write") and Write_Error.Failed, "write exception contained");
   Reset; Step := -Milliseconds (1);
   Check (not Backwards.Try_Line ("reverse") and Backwards.Failed, "backwards clock rejected");
   Check (Used = 0, "reverse never writes");
   Reset; Step := Milliseconds (10);
   Check (not Slow_Line.Try_Line ("many characters"), "whole-line budget with ready UART");
   Check (Used = 2 and Slow_Line.Failed, "successful bytes do not renew deadline");
   Put_Line ("PASS" & Natural'Image (Checks) & " bounded logger checks (mock transport)");
end Logger_Tests;
