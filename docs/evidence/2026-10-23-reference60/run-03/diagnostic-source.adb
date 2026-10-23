with Ada.Real_Time; use Ada.Real_Time;
with MicroBit; use MicroBit;
with MicroBit.Console; use MicroBit.Console;
with Adaptive_Echo;
with Adaptive_Range_Model; use Adaptive_Range_Model;
with Ada.Exceptions;
procedure Sensor_GPIO_Diagnostic is
   package Front is new Adaptive_Echo (MB_P13, MB_P1);
   package Left is new Adaptive_Echo (MB_P14, MB_P2);
   package Right is new Adaptive_Echo (MB_P15, MB_P8);
   Epoch : Time;
   Next_Trigger : Time := Time_First;
   Previous_Trigger : Time := Time_First;
   Sequence : Natural := 0;
   function Us (Span : Time_Span) return Natural is
     (Natural (To_Duration (Span) * 1_000_000.0));
   procedure Sample (Phase : String; Sensor : Character; Interval : Positive) is
      R : Echo_Result;
      Trigger_Time : Time;
      Gap : Natural := 0;
      Distance_Milli_CM : Natural;
   begin
      delay until Next_Trigger;
      Trigger_Time := Clock;
      if Previous_Trigger /= Time_First then
         Gap := Us (Trigger_Time - Previous_Trigger);
      end if;
      Previous_Trigger := Trigger_Time;
      Next_Trigger := Trigger_Time + Milliseconds (Interval);
      case Sensor is
         when 'F' => R := Front.Read;
         when 'L' => R := Left.Read;
         when 'R' => R := Right.Read;
         when others => raise Constraint_Error;
      end case;
      Sequence := Sequence + 1;
      Distance_Milli_CM := Natural (R.Distance_CM * 1000.0);
      Put_Line ("DATA," & Natural'Image (Sequence) & "," & Phase & ","
                & Sensor & "," & Natural'Image (Us (Trigger_Time - Epoch))
                & "," & Positive'Image (Interval) & "," & Natural'Image (Gap)
                & "," & Echo_Status'Image (R.Status)
                & "," & Natural'Image (R.Pulse_Us)
                & "," & Natural'Image (R.Elapsed_Us)
                & "," & Natural'Image (Distance_Milli_CM)
                & "," & Natural'Image (R.Legacy_Count_CM));
   end Sample;
begin
   Put_Line ("ADAptive SENSOR GPIO DIAGNOSTIC v3; NO_MOTOR_WRITES; RISE_TIMEOUT_US=10000");
   -- Motor power MUST be physically disconnected. This image does not
   -- initialize I2C or servo outputs, and cannot electrically guarantee stop.
   Put_Line ("REQUIRES_EXTERNAL_MOTOR_POWER_OFF; NO_I2C; NO_SERVO_WRITES");
   delay 0.8;
   Epoch := Clock;
   Put_Line ("seq,phase,sensor,t_us,interval_ms,trigger_gap_us,status,pulse_us,elapsed_us,distance_milli_cm,legacy_cm");
   for I in 1 .. 40 loop
      Sample ("ALL_65", 'F', 65); Sample ("ALL_65", 'L', 65);
      Sample ("ALL_65", 'R', 65);
   end loop;
   for I in 1 .. 40 loop
      Sample ("ALL_100", 'F', 100); Sample ("ALL_100", 'L', 100);
      Sample ("ALL_100", 'R', 100);
   end loop;
   for I in 1 .. 40 loop Sample ("LEFT_65", 'L', 65); end loop;
   for I in 1 .. 40 loop Sample ("LEFT_100", 'L', 100); end loop;
   Put_Line ("DONE,320,NO_MOTOR_WRITES");
   loop delay 1.0; end loop;
exception
   when E : others =>
      Put_Line ("DIAGNOSTIC FAULT " & Ada.Exceptions.Exception_Name (E));
      loop delay 1.0; end loop;
end Sensor_GPIO_Diagnostic;
