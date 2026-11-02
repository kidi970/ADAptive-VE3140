with Ada.Text_IO; use Ada.Text_IO;
with Ada.Exceptions; use Ada.Exceptions;
with HAL; use HAL;
with HAL.I2C; use HAL.I2C;
with MicroBit.I2C; use MicroBit.I2C;
with MicroBit.Buttons;
with Adaptive_Safety; use Adaptive_Safety;
with Adaptive_Motion; use Adaptive_Motion;
with Adaptive_Policy; use Adaptive_Policy;
with Adaptive_Errors; use Adaptive_Errors;
procedure Motion_Tests is
   Checks : Natural := 0;
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if not Condition then raise Program_Error with Name; end if;
      Checks := Checks + 1;
   end Check;
begin
   begin
      Drive (Straight);
      Check (False, "drive before init must raise");
   exception when Motor_Not_Ready => null;
   end;
   Check (Calls = 0, "no I2C command before initialization");
   Adaptive_Motion.Initialize;
   Check (Motor_Stop_Acknowledged and not Motion_Commanded, "startup stops");
   declare
      Before : constant Natural := Calls;
   begin
      Drive (Straight);
      Check (False, "drive before arming must raise");
   exception
      when Motor_Not_Ready => Check (Calls = Before, "unarmed drive never reaches bus");
   end;
   Request_Start;
   for I in 1 .. 8 loop
      Check (Trace (I).Register = UInt8 (16#09# + 4 * (I - 1))
             and Trace (I).Value = 16#10# and Trace (I).Length = 2,
             "all eight motor channels off before controller wake");
   end loop;
   Check (Trace (9).Register = 0 and Trace (9).Value = 16#10#,
          "sleep follows safe outputs");
   for I in 1 .. Calls loop
      Check (Trace (I).Timeout = 20, "bounded bus writes");
   end loop;
   Reset_Trace;
   Drive (Straight);
   Check (Motion_Commanded and not Motor_Stop_Acknowledged, "drive flags");
   Stop;
   Check (Calls = 2 and Trace (2).Length = 33, "known AI permits burst stop");
   for Channel in 0 .. 7 loop
      Check (Last_Data (4 + 4 * Channel) = 16#10#, "FULL_OFF on every motor PWM channel");
   end loop;
   Check (not Motion_Commanded and Motor_Stop_Acknowledged, "acknowledged stop");
   Reset_Trace;
   Request_Stop;
   begin
      Drive (Left);
      Check (False, "latched drive must raise");
   exception when Stop_Latched_Error => null;
   end;
   Check (Calls = 0, "latched drive never reaches bus");
   begin
      Adaptive_Motion.Initialize;
      Check (False, "reinitialization cannot clear stop latch");
   exception when Stop_Latched_Error => null;
   end;
   Check (Calls = 0, "latched init never reaches bus");
   -- Resetting the flag here is test-fixture setup; firmware has no reset UI.
   Stop_Requested := False;
   Adaptive_Motion.Initialize;
   Reset_Trace;
   begin
      Aim (0);
      Check (False, "invalid servo must raise");
   exception when Servo_Limit_Error => null;
   end;
   Check (Calls = 0, "invalid angle never reaches bus");
   for Failure in I2C_Status range Err_Error .. Busy loop
      Stop_Requested := False; Reset_Trace; Adaptive_Motion.Initialize; Reset_Trace;
      Inject_Status := Failure; Fail_At := 1;
      begin
         Drive (Right);
         Check (False, "injected I2C error must raise");
      exception
         when E : Motor_Bus_Error =>
            Check (Exception_Message (E)'Length > 0, "bus fault context");
      end;
      Check (Stop_Requested and not Motor_Stop_Acknowledged, "bus fault latches");
      Reset_Trace;
      Stop;
      Check (Calls = 8, "unknown AI uses independent channel off writes");
      Check (Motor_Stop_Acknowledged, "fallback stop acknowledged");
   end loop;
   Stop_Requested := False; Reset_Trace; Adaptive_Motion.Initialize; Reset_Trace;
   Drive (Straight);
   Fail_At := 2;
   begin
      Stop;
      Check (False, "failed stop must raise");
   exception when Motor_Bus_Error => null;
   end;
   Check (Motion_Commanded and not Motor_Stop_Acknowledged,
          "failed stop cannot claim motor stopped");
   Stop_Requested := False; Reset_Trace; Adaptive_Motion.Initialize; Reset_Trace;
   Stop_During_Write := True;
   begin
      Drive (Straight);
      Check (False, "stop during drive write must raise");
   exception when Stop_Latched_Error => null;
   end;
   Check (Stop_Requested and not Motion_Commanded and Motor_Stop_Acknowledged,
          "interrupt during transmit followed by stop");
   -- The previously observed startup PROGRAM_ERROR had no stage detail.
   -- Inject a transport error at every write in the actual startup sequence.
   for Stage in 1 .. 12 loop
      Stop_Requested := False; Reset_Trace;
      Fail_At := Stage;
      begin
         Adaptive_Motion.Initialize;
         Check (False, "partial initialization must raise");
      exception when Motor_Bus_Error => null;
      end;
      Check (Calls = Stage and Stop_Requested and not Motor_Stop_Acknowledged,
             "startup failure inhibits motion at every stage");
      Reset_Trace;
      begin
         Drive (Straight);
         Check (False, "partial startup must inhibit drive");
      exception when Stop_Latched_Error => null;
      end;
      Check (Calls = 0, "no drive command after partial startup");
   end loop;
   MicroBit.Buttons.Subscription_Accepted := False;
   begin
      Adaptive_Safety.Initialize;
      Check (False, "stop button setup failure must raise");
   exception when Safety_Setup_Error => null;
   end;
   Put_Line ("PASS" & Natural'Image (Checks) & " motion checks (mock I2C)");
end Motion_Tests;
