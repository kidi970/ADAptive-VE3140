with Ada.Real_Time; use Ada.Real_Time;
with MicroBit.Music; use MicroBit.Music;
with MicroBit.Types; use MicroBit.Types;
with System;

package body Proximity_Alert is
   Poll_Period : constant Time_Span := Milliseconds (10);
   Pip : constant Melody := (1 => (C6, 70));

   protected Timing is
      procedure Set_Interval (Interval : Time_Span);
      function Get_Interval return Time_Span;
   private
      Current_Interval : Time_Span := Time_Span_Zero;
   end Timing;

   protected body Timing is
      procedure Set_Interval (Interval : Time_Span) is
      begin
         Current_Interval := Interval;
      end Set_Interval;

      function Get_Interval return Time_Span is (Current_Interval);
   end Timing;

   function FareIndikasjon (Distance : Distance_cm) return Time_Span is
   begin
      if Distance = 0 then
         return Time_Span_Zero;
      elsif Distance <= 15 then
         return Milliseconds (140);
      elsif Distance <= 30 then
         return Milliseconds (400);
      elsif Distance <= 45 then
         return Milliseconds (820);
      else
         return Time_Span_Zero;
      end if;
   end FareIndikasjon;

   procedure Set_Distance (Distance : Distance_cm) is
   begin
      Timing.Set_Interval (FareIndikasjon (Distance));
   end Set_Distance;

   task Speaker_Task with Priority => System.Priority'First;

   task body Speaker_Task is
      Last_Beep : Time := Time_First;
      Now, Next_Check : Time;
      Interval : Time_Span;
   begin
      loop
         Now := Clock;
         Next_Check := Now + Poll_Period;
         Interval := Timing.Get_Interval;

         if Interval = Time_Span_Zero then
            Last_Beep := Time_First;
         elsif Last_Beep = Time_First or else Now >= Last_Beep + Interval then
            Last_Beep := Now;
            Play (27, Pip);
         elsif Last_Beep + Interval < Next_Check then
            Next_Check := Last_Beep + Interval;
         end if;

         delay until Next_Check;
      end loop;
   end Speaker_Task;
end Proximity_Alert;
