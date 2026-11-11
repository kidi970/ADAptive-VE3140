with Adaptive_Policy; use Adaptive_Policy;
package Adaptive_Sensors is
   type Sensor is (Front, Left, Right);
   -- Call after motor stop and before permitting a start. P8 is NFC2 on V2.
   procedure Initialize;
   function Raw (Which : Sensor) return Distance;
   function Filtered (Which : Sensor) return Distance;
   function Read_All return Snapshot;
end Adaptive_Sensors;
