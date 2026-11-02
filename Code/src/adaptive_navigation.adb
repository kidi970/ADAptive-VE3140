with Adaptive_Sensors; use Adaptive_Sensors;
with Adaptive_Motion;
with Adaptive_Display;
with Ada.Real_Time; use Ada.Real_Time;
with Adaptive_Quick_Scan;
with Adaptive_Safety;
with MicroBit.Console; use MicroBit.Console;
package body Adaptive_Navigation is
   Previous : Choice := Blocked;
   function Scan_Path return Choice is
      Started : constant Time := Clock;
      Current_Angle : Natural := Center;
      function Now_Ms return Natural is
        (Natural (To_Duration (Clock - Started) * 1_000.0));
      function Stop_Requested return Boolean is
        (Adaptive_Safety.Stop_Requested);
      procedure Recenter is
      begin
         if Current_Angle /= Center and then not Stop_Requested then
            Adaptive_Motion.Aim (Center);
            Current_Angle := Center;
            delay 0.5;
         end if;
      end Recenter;
      procedure Point (Angle : Natural; Value : out Distance;
                       Sample_Started_Ms : out Natural) is
      begin
         if Stop_Requested then
            Value := 0; Sample_Started_Ms := Now_Ms; return;
         end if;
         Adaptive_Motion.Aim (Angle);
         Current_Angle := Angle;
         -- Keep the old settling allowance until the SG90 slew is measured.
         delay 0.5;
         Sample_Started_Ms := Now_Ms;
         Value := Filtered (Front);
         Put_Line ("SCAN ANGLE" & Natural'Image (Angle)
                   & " CM" & Distance'Image (Value));
      end Point;
      package Search is new Adaptive_Quick_Scan
        (Recenter, Point, Read_All, Now_Ms, Stop_Requested);
      Result : Search.Scan_Result;
   begin
      Adaptive_Motion.Stop;
      Adaptive_Display.Show_Status ("STATUS: SCAN");
      Adaptive_Motion.Aim (Center); delay 0.5;
      Result := Search.Find (Previous);
      if Result.Direction in Left | Right then Previous := Result.Direction; end if;
      Adaptive_Display.Show_Direction
        ((case Result.Direction is
             when Left => 'L', when Right => 'R',
             when Straight => 'F', when Blocked => 'S'));
      Put_Line ("SCAN END POINTS" & Natural'Image (Result.Points)
                & " EXPIRED" & Natural'Image (Result.Expired_Pairs)
                & " ELAPSED_MS" & Natural'Image (Now_Ms)
                & " CHOICE " & Choice'Image (Result.Direction));
      return Result.Direction;
   end Scan_Path;
   function Monitor_Motion (Turning : Boolean := False) return Boolean is
      D : Distance;
      function Check (Which : Sensor) return Boolean is
         Limit : Natural := Side_Distance;
      begin
         if Adaptive_Safety.Stop_Requested then
            Adaptive_Motion.Stop;
            return False;
         end if;
         if Turning then Limit := Turn_Distance;
         elsif Which = Front then Limit := Stop_Distance; end if;
         D := Raw (Which);
         if not Clear (D, Limit) then
            -- Stop before logging, display updates, or any further sample.
            Adaptive_Motion.Stop;
            Put_Line ("MOTION STOP " & Sensor'Image (Which)
                      & " CM" & Distance'Image (D));
            return False;
         end if;
         return True;
      end Check;
   begin
      -- Front is revisited between the two side sensors (nominal 130 ms).
      return Check (Front) and then Check (Left)
        and then Check (Front) and then Check (Right);
   end Monitor_Motion;
end Adaptive_Navigation;
