with Ada.Real_Time; use Ada.Real_Time;
with MicroBit.TimeHighspeed;
with Adaptive_Range_Model; use Adaptive_Range_Model;
package body Adaptive_Echo is
   Trigger : nRF.GPIO.GPIO_Point := Trigger_Pin;
   Echo : nRF.GPIO.GPIO_Point := Echo_Pin;
   function Microseconds (Span : Time_Span) return Natural is
     (Natural (To_Duration (Span) * 1_000_000.0));
   function Read return Echo_Result is
      R : Echo_Result;
      Started : constant Time := Clock;
      Deadline, Rise : Time;
      procedure Finish is
      begin R.Elapsed_Us := Microseconds (Clock - Started); end Finish;
   begin
      if Echo.Set then
         R.Status := Echo_Already_High; Finish; return R;
      end if;
      Trigger.Set;
      MicroBit.TimeHighspeed.Delay_Us (10);
      Trigger.Clear;
      Deadline := Clock + Milliseconds (3);
      loop
         exit when Echo.Set;
         if Clock >= Deadline then
            R.Status := No_Rise; Finish; return R;
         end if;
      end loop;
      Rise := Clock;
      Deadline := Rise + Milliseconds (23);
      -- Preserve the legacy 58-us polling structure for paired comparison.
      -- Both values are diagnostics, not interchangeable calibrated distances.
      while Clock < Deadline loop
         if not Echo.Set then
            R.Pulse_Us := Microseconds (Clock - Rise);
            R.Distance_CM := Pulse_Distance (R.Pulse_Us);
            if Working_Range (R.Distance_CM) then R.Status := Valid_Echo;
            else R.Status := Outside_Working_Range; end if;
            Finish; return R;
         end if;
         MicroBit.TimeHighspeed.Delay_Us (58);
         R.Legacy_Count_CM := R.Legacy_Count_CM + 1;
      end loop;
      R.Status := No_Fall;
      R.Pulse_Us := Microseconds (Clock - Rise);
      -- A timed-out pulse never produces a usable distance.
      R.Distance_CM := 0.0;
      Finish; return R;
   end Read;
begin
   Trigger.Configure_IO
     ((Mode => nRF.GPIO.Mode_Out, Resistors => nRF.GPIO.No_Pull,
       Input_Buffer => nRF.GPIO.Input_Buffer_Connect,
       Sense => nRF.GPIO.Sense_Disabled, Drive => nRF.GPIO.Drive_S0S1));
   Trigger.Clear;
   Echo.Configure_IO
     ((Mode => nRF.GPIO.Mode_In, Resistors => nRF.GPIO.No_Pull,
       Input_Buffer => nRF.GPIO.Input_Buffer_Connect,
       Sense => nRF.GPIO.Sense_Disabled, Drive => nRF.GPIO.Drive_S0S1));
end Adaptive_Echo;
