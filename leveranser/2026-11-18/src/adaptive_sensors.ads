with Adaptive_Policy; use Adaptive_Policy;
package Adaptive_Sensors is
   type Sensor is (Front, Left, Right);
   function Raw (Which : Sensor) return Distance;
   function Filtered (Which : Sensor) return Distance;
   function Read_All return Snapshot;
end Adaptive_Sensors;
