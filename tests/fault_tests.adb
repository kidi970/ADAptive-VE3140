with Ada.Text_IO; use Ada.Text_IO;
with Ada.Exceptions; use Ada.Exceptions;
with Adaptive_Errors; use Adaptive_Errors;
with Adaptive_Fault_Handler;
procedure Fault_Tests is
   Checks : Natural := 0;
   Stop_Fails, Log_Fails, Latched : Boolean := False;
   Stop_Calls, Log_Calls : Natural := 0;
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if not Condition then raise Program_Error with Name; end if;
      Checks := Checks + 1;
   end Check;
   procedure Latch is
   begin
      Latched := True;
   end Latch;
   procedure Stop is
   begin
      Check (Latched, "latch precedes stop");
      Stop_Calls := Stop_Calls + 1;
      if Stop_Fails then raise Motor_Bus_Error with "injected stop failure"; end if;
   end Stop;
   procedure Log (Message : String) is
   begin
      Check (Latched and Stop_Calls > 0, "stop attempted before logging");
      Log_Calls := Log_Calls + 1;
      Check (Message'Length > 0, "diagnostic exists");
      if Log_Fails then raise Program_Error with "injected logger failure"; end if;
   end Log;
   package Normal is new Adaptive_Fault_Handler (Latch, Stop, Log);
   package Bus_Failure is new Adaptive_Fault_Handler (Latch, Stop, Log);
   package Log_Failure is new Adaptive_Fault_Handler (Latch, Stop, Log);
   package Both_Fail is new Adaptive_Fault_Handler (Latch, Stop, Log);
   use type Normal.Stop_Result;
   use type Bus_Failure.Stop_Result;
   use type Log_Failure.Stop_Result;
   use type Both_Fail.Stop_Result;
begin
   Check (Classify (Motor_Bus_Error'Identity) = Motor_Bus_Fault, "bus classifier");
   Check (Classify (Motor_Not_Ready'Identity) = Initialization_Fault, "init classifier");
   Check (Classify (Servo_Limit_Error'Identity) = Servo_Range_Fault, "servo classifier");
   Check (Classify (Stop_Latched_Error'Identity) = Stop_Latch_Fault, "latch classifier");
   Check (Classify (Safety_Setup_Error'Identity) = Safety_Setup_Fault, "button classifier");
   Check (Classify (Constraint_Error'Identity) = Constraint_Fault, "range classifier");
   Check (Classify (Program_Error'Identity) = Program_Fault, "program classifier");
   Check (Classify (Storage_Error'Identity) = Storage_Fault, "storage classifier");
   Check (Classify (Tasking_Error'Identity) = Unexpected_Fault, "unknown classifier");
   Check (not Normal.Status.Latched, "starts unlatched");
   begin
      raise Servo_Limit_Error with "test range";
   exception
      when E : others => Normal.Handle (E);
   end;
   Check (Normal.Status.Latched and Normal.Status.Primary = Servo_Range_Fault,
          "exception propagates into recovery");
   Check (Normal.Status.Stop_Command = Normal.Acknowledged, "stop acknowledged");
   Check (not Normal.Status.Logging_Failed, "normal diagnostics");
   begin
      raise Constraint_Error;
   exception
      when E : others => Normal.Handle (E);
   end;
   Check (Stop_Calls = 1 and Normal.Status.Primary = Servo_Range_Fault,
          "repeat fault cannot retry or replace cause");
   Stop_Fails := True;
   begin
      raise Constraint_Error;
   exception
      when E : others => Bus_Failure.Handle (E);
   end;
   Check (Bus_Failure.Status.Primary = Constraint_Fault, "original fault preserved");
   Check (Bus_Failure.Status.Stop_Command = Bus_Failure.Failed
          and Bus_Failure.Status.Stop_Fault = Motor_Bus_Fault,
          "secondary stop failure recorded");
   Stop_Fails := False; Log_Fails := True;
   begin
      raise Motor_Bus_Error;
   exception
      when E : others => Log_Failure.Handle (E);
   end;
   Check (Log_Failure.Status.Stop_Command = Log_Failure.Acknowledged
          and Log_Failure.Status.Logging_Failed, "logger cannot undo recovery");
   Stop_Fails := True;
   begin
      raise Program_Error;
   exception
      when E : others => Both_Fail.Handle (E);
   end;
   Check (Both_Fail.Status.Primary = Program_Fault
          and Both_Fail.Status.Stop_Command = Both_Fail.Failed
          and Both_Fail.Status.Logging_Failed, "combined failure contained");
   Check (Stop_Calls = 4, "one bounded stop per fault boundary");
   Put_Line ("PASS" & Natural'Image (Checks) & " fault checks");
end Fault_Tests;
