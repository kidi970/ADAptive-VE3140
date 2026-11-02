with Ada.Real_Time; use Ada.Real_Time;
with MicroBit; use MicroBit;
with MicroBit.Ultrasonic;
with MicroBit.Console; use MicroBit.Console;
package body Adaptive_Sensors is
   package Front_Sensor is new MicroBit.Ultrasonic (MB_P13, MB_P1);
   package Left_Sensor is new MicroBit.Ultrasonic (MB_P14, MB_P2);
   package Right_Sensor is new MicroBit.Ultrasonic (MB_P15, MB_P8);
   Next_Trigger : Time := Time_First;
   function Raw (Which : Sensor) return Distance is
      D : Distance;
   begin
      -- One acoustic transmitter at a time; at least 65 ms between triggers.
      delay until Next_Trigger;
      Next_Trigger := Clock + Milliseconds (65);
      case Which is
         when Front => D := Distance (Front_Sensor.Read);
         when Left => D := Distance (Left_Sensor.Read);
         when Right => D := Distance (Right_Sensor.Read);
      end case;
      return D;
   end Raw;
   function Filtered (Which : Sensor) return Distance is
      A, B, C : Distance;
   begin
      A := Raw (Which); B := Raw (Which); C := Raw (Which);
      -- Filtered is used only while stopped; never log between cruise samples.
      Put_Line ("RAW " & Sensor'Image (Which) & Distance'Image (A)
                & Distance'Image (B) & Distance'Image (C)
                & " FILTER" & Distance'Image (Filter (A, B, C)));
      return Filter (A, B, C);
   end Filtered;
   function Read_All return Snapshot is
      S : Snapshot;
   begin
      S.Front := Filtered (Front);
      S.Left := Filtered (Left);
      S.Right := Filtered (Right);
      return S;
   end Read_All;
end Adaptive_Sensors;
