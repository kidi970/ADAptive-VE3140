with Ada.Real_Time; use Ada.Real_Time;
with Adaptive_Log; use Adaptive_Log;
with Adaptive_USB_IO;
with Adaptive_Range_Model;
with Ada.Exceptions;
procedure Standalone_USB is
   Next : Time := Clock;
   A, B : Boolean;
   procedure Illuminate_Until (Deadline : Time) is
      Release : Time;
      function Earlier (A, B : Time) return Time is
        (if A < B then A else B);
   begin
      -- Match DisplayRT's nominal centre-pixel duty (900 us per 25 slots).
      -- Do not hold a multiplexed LED continuously on after removing its
      -- scanning timer. These are scheduled values, not measured waveforms.
      while Clock < Deadline loop
         Release := Clock;
         Adaptive_USB_IO.Center_On;
         delay until Earlier (Release + Microseconds (900), Deadline);
         Adaptive_USB_IO.Center_Off;
         delay until Earlier (Release + Microseconds (22_500), Deadline);
      end loop;
   end Illuminate_Until;
begin
   Adaptive_USB_IO.Initialize;
   Put_Line ("ADAptive USB SELFTEST v1; NO_MOTOR_WRITES; NO_I2C");
   if abs (Adaptive_Range_Model.Pulse_Distance (3480) - 60.0) > 0.01 then
      raise Program_Error with "Pure pulse model regression";
   end if;
   Put_Line ("MODEL,PASS,PULSE_US=3480,NOMINAL_CM=60; NOT_A_SENSOR_MEASUREMENT");
   Next := Clock;
   for I in 1 .. 12 loop
      A := Adaptive_USB_IO.Button_A_Pressed;
      B := Adaptive_USB_IO.Button_B_Pressed;
      Put_Line ("TICK," & Positive'Image (I) & ",A="
        & (if A then "PRESSED" else "RELEASED") & ",B="
        & (if B then "PRESSED" else "RELEASED"));
      Next := Next + Milliseconds (250); Illuminate_Until (Next);
      Adaptive_USB_IO.Center_Off;
      Next := Next + Milliseconds (250); delay until Next;
   end loop;
   Put_Line ("DONE,USB_SELFTEST,12");
   loop
      Illuminate_Until (Clock + Milliseconds (500));
      delay 0.5;
   end loop;
exception
   when E : others =>
      begin
         Adaptive_USB_IO.Center_Off;
      exception
         when others => null;
      end;
      Put_Line ("SELFTEST_FAULT," & Ada.Exceptions.Exception_Name (E));
      loop delay 1.0; end loop;
end Standalone_USB;
