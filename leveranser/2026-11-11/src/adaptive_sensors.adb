with Ada.Real_Time; use Ada.Real_Time;
with MicroBit; use MicroBit;
with Adaptive_Echo;
with Adaptive_Range_Model; use Adaptive_Range_Model;
with Adaptive_Safety;
with Adaptive_Log; use Adaptive_Log;
with NRF_SVD.UICR;
package body Adaptive_Sensors is
   procedure Initialize is
      use type NRF_SVD.UICR.NFCPINS_PROTECT_Field;
   begin
      if NRF_SVD.UICR.UICR_Periph.NFCPINS.PROTECT /= NRF_SVD.UICR.Disabled then
         Put_Line ("SENSOR CONFIG FAULT: P8 IS NFC; GPIO PROVISIONING REQUIRED");
         raise Program_Error with "P8 NFC mode blocks right echo";
      end if;
      Put_Line ("SENSOR PIN CHECK: P15 TRIG; P8 ECHO; NFC DISABLED");
   end Initialize;
   package Front_Sensor is new Adaptive_Echo
     (MB_P13, MB_P1, Float (Front_Max_Distance));
   package Left_Sensor is new Adaptive_Echo
     (MB_P14, MB_P2, Float (Side_Max_Distance));
   package Right_Sensor is new Adaptive_Echo
     (MB_P15, MB_P8, Float (Side_Max_Distance));
   Next_Trigger : Time := Time_First;
   function Acquire (Which : Sensor) return Echo_Result is
   begin
      delay until Next_Trigger;
      Next_Trigger := Clock + Milliseconds (65);
      case Which is
         when Front => return Front_Sensor.Read;
         when Left  => return Left_Sensor.Read;
         when Right => return Right_Sensor.Read;
      end case;
   end Acquire;

   function Policy_Distance (Reading : Echo_Result) return Distance is
   begin
      if Reading.Status = Valid_Echo then
         return Distance (Reading.Distance_CM);
      end if;
      -- The existing route policy uses zero as its rejection sentinel.
      -- Only acquisition and diagnostics retain the precise reason.
      return 0;
   end Policy_Distance;

   function Raw (Which : Sensor) return Distance is
   begin
      if Adaptive_Safety.Stop_Requested then return 0; end if;
      return Policy_Distance (Acquire (Which));
   end Raw;

   function Filtered (Which : Sensor) return Distance is
      Values : Distances (1 .. 3);
      Reading : Echo_Result;
   begin
      for I in Values'Range loop
         if Adaptive_Safety.Stop_Requested then return 0; end if;
         Reading := Acquire (Which);
         Values (I) := Policy_Distance (Reading);
         case Reading.Status is
            when Valid_Echo | Outside_Working_Range =>
               Put_Line ("ECHO " & Sensor'Image (Which) & " "
                         & Echo_Status'Image (Reading.Status)
                         & " CM" & Natural'Image (Natural (Reading.Distance_CM)));
            when others =>
               Put_Line ("ECHO " & Sensor'Image (Which) & " "
                         & Echo_Status'Image (Reading.Status)
                         & " CM UNKNOWN");
         end case;
      end loop;
      return Filter (Values (1), Values (2), Values (3));
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
