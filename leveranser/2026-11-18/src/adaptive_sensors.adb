with Ada.Real_Time; use Ada.Real_Time;
with MicroBit; use MicroBit;
with Adaptive_Echo;
with Adaptive_Range_Model; use Adaptive_Range_Model;
with Adaptive_Open_Range;
with Adaptive_Log; use Adaptive_Log;
with Adaptive_Safety;
package body Adaptive_Sensors is
   -- Installed front module completes a no-return pulse near 60 ms. Wait
   -- for the falling edge; a 45 ms cutoff cannot distinguish it from a fault.
   package Front_Sensor is new Adaptive_Echo (MB_P13, MB_P1, 70);
   package Left_Sensor is new Adaptive_Echo (MB_P14, MB_P2, 70);
   package Right_Sensor is new Adaptive_Echo (MB_P15, MB_P8, 70);
   Next_Trigger : Time := Time_First;
   -- Read-only debug evidence: retain the actual acquisition failure instead
   -- of losing its cause when the policy maps it to unknown. No text or bus
   -- traffic is added to the live motion monitor.
   type Echo_Telemetry is record
      Status_Code : Natural := Echo_Status'Pos (No_Rise);
      Pulse_Us : Natural := 0;
      Elapsed_Us : Natural := 0;
   end record with Convention => C;
   type Telemetry_Array is array (Sensor) of Echo_Telemetry
     with Convention => C, Volatile_Components;
   Latest : Telemetry_Array := (others => <>)
     with Export, Convention => C,
          External_Name => "adaptive_latest_echo";
   function Raw (Which : Sensor) return Distance is
      D : Distance;
      R : Echo_Result;
   begin
      -- One acoustic transmitter at a time; at least 65 ms between triggers.
      if Adaptive_Safety.Stop_Requested then return 0; end if;
      if Next_Trigger > Clock then delay until Next_Trigger; end if;
      if Adaptive_Safety.Stop_Requested then return 0; end if;
      Next_Trigger := Clock + Milliseconds (65);
      case Which is
         when Front => R := Front_Sensor.Read;
         when Left => R := Left_Sensor.Read;
         when Right => R := Right_Sensor.Read;
      end case;
      Latest (Which) := (Echo_Status'Pos (R.Status), R.Pulse_Us, R.Elapsed_Us);
      D := Adaptive_Open_Range.Classify (R);
      return D;
   end Raw;
   function Filtered (Which : Sensor) return Distance is
      A, B, C : Distance;
   begin
      A := Raw (Which); B := Raw (Which); C := Raw (Which);
      -- Filtered is used only while stopped; never log between cruise samples.
      declare
         function Evidence (D : Distance) return String is
           (if D = Open_Range then " OPEN"
            elsif D = 0 then " UNKNOWN" else Distance'Image (D) & "CM");
      begin
         Put_Line ("RAW " & Sensor'Image (Which) & Evidence (A)
                   & Evidence (B) & Evidence (C)
                   & " FILTER" & Evidence (Filter (A, B, C)));
      end;
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
