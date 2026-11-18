with Adaptive_Policy; use Adaptive_Policy;
package Adaptive_Scan_Policy with Pure is
   Max_Pair_Age_Ms : constant := 2_000;
   -- Design freshness budget from the oldest ray until the drive command. This is
   -- not a certified collision bound for moving obstacles or a moving car.
   -- Each side pair covers 20 degrees within the verified servo envelope.
   Pair_Span_Degrees : constant := 20;
   Corner_Angle : constant := 15;
   Wall_Probe_Range : constant := 40;
   Wall_Release_Distance : constant := 60;
   Wall_Release_Side_Distance : constant := 25;
   Side_Approach_Distance : constant := 30;
   -- A 16 x 23 cm footprint gains roughly 6 cm of lateral corner
   -- overhang while pivoting. Leave additional room around both sides.
   Pivot_Tail_Clearance : constant := 11;
   Pivot_Target_Clearance : constant := Side_Distance;
   function Pivot_Side_Too_Close (D : Distance) return Boolean is
     (Valid (D) and then D <= Pivot_Tail_Clearance);
   function Pivot_Side_Limit (Direction, Side : Choice) return Natural;
   function Rotation_Clear (Guard : Snapshot; Direction : Choice;
                            Allow_Open : Boolean := False) return Boolean;
   function Near_Wall_Clear (Guard : Snapshot; Direction : Choice;
                             Wall_Limit : Natural := Wall_Release_Side_Distance) return Boolean;
   function Wall_Rotation_Clear (Guard : Snapshot) return Boolean;
   function Wall_Guard_Clear (Guard : Snapshot) return Boolean;
   function Wall_Profile (Guard : Snapshot; Right_Ray, Left_Ray : Distance)
                          return Boolean;
   function Wall_Exit_Clear (Guard : Snapshot; Right_Ray, Left_Ray : Distance;
                             Direction : Choice) return Boolean;
   type Scan_Rejection is
     (Ray_Unknown, Ray_Open, Ray_Too_Close, Corridor_Too_Narrow,
      Guard_Not_Clear, Evidence_Expired, Invalid_Timestamp);
   type Angle_Pair is array (1 .. 2) of Natural;
   function Angles (Direction : Choice) return Angle_Pair;
   function Preferred (S : Snapshot; Previous : Choice) return Choice;
   function Acceptable (Pair : Distances; Guard : Snapshot; Direction : Choice;
                        Age_Ms : Natural) return Boolean;
end Adaptive_Scan_Policy;
