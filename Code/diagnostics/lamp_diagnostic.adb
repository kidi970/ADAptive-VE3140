with Ada.Real_Time; use Ada.Real_Time;
with Adaptive_Log; use Adaptive_Log;
with Adaptive_Lights;
with Adaptive_Lamp_Policy; use Adaptive_Lamp_Policy;
with Adaptive_Lamp_Control;
with Adaptive_Safety;
procedure Lamp_Diagnostic is
   type Mode_List is array (Positive range <>) of Lamp_Mode;
   Sequence : constant Mode_List := (Parked, Turning_Left, Turning_Right, Moving, Braking);
   Next : Time;
begin
   Put_Line ("ADAptive LAMP DIAGNOSTIC v1; NO_MOTOR_I2C; P0_BRAKE P12_LEFT P16_RIGHT");
   Adaptive_Safety.Initialize;
   Adaptive_Lights.Initialize;
   for Mode of Sequence loop
      exit when Adaptive_Safety.Stop_Requested or Adaptive_Lights.Failed;
      Adaptive_Lamp_Control.State.Set_Mode (Mode);
      Put_Line ("LAMPS " & Lamp_Mode'Image (Mode));
      Next := Clock;
      for Tick in 1 .. 60 loop
         exit when Adaptive_Safety.Stop_Requested or Adaptive_Lights.Failed;
         Next := Next + Milliseconds (50);
         delay until Next;
      end loop;
   end loop;
   Adaptive_Lamp_Control.State.Latch_Fault;
   Put_Line ("LAMPS FAULTED; RED STEADY, BOTH INDICATORS BLINK; NO_MOTOR_I2C");
   loop delay 1.0; end loop;
exception
   when others =>
      Adaptive_Safety.Request_Stop;
      Adaptive_Lamp_Control.State.Latch_Fault;
      Put_Line ("LAMP DIAGNOSTIC FAULT; NO_MOTOR_I2C");
      loop delay 1.0; end loop;
end Lamp_Diagnostic;
