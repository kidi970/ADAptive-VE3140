with Adaptive_Policy; use Adaptive_Policy;
package Adaptive_Scan_Policy with Pure is
   Max_Pair_Age_Ms : constant := 2_000;
   -- Design freshness budget for stationary candidate selection. This is
   -- not a certified collision bound for moving obstacles or a moving car.
   type Angle_Pair is array (1 .. 2) of Natural;
   function Angles (Direction : Choice) return Angle_Pair;
   function Preferred (S : Snapshot; Previous : Choice) return Choice;
   function Acceptable (Pair : Distances; Guard : Snapshot; Age_Ms : Natural)
                        return Boolean;
end Adaptive_Scan_Policy;
