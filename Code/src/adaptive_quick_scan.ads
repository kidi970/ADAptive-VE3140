with Adaptive_Policy; use Adaptive_Policy;
generic
   with procedure Recenter;
   with procedure Point (Angle : Natural; Value : out Distance;
                         Sample_Started_Ms : out Natural);
   with function Read_Guard return Snapshot;
   with function Now_Ms return Natural;
   with function Stop_Requested return Boolean;
package Adaptive_Quick_Scan is
   type Scan_Result is record
      Direction : Choice := Blocked;
      Points : Natural range 0 .. 4 := 0;
      Expired_Pairs : Natural range 0 .. 2 := 0;
   end record;
   -- Stationary first-feasible search. At most four side rays, including
   -- early rejection of an unknown/blocked ray. Never drives a motor.
   function Find (Previous : Choice := Blocked) return Scan_Result;
end Adaptive_Quick_Scan;
