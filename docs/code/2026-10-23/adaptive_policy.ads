package Adaptive_Policy with Pure is
   subtype Distance is Natural range 0 .. 400;
   type Distances is array (Positive range <>) of Distance;
   type Choice is (Blocked, Straight, Right, Left);
   type Snapshot is record
      Front, Left, Right : Distance := 0;
   end record;
   Center : constant := 84;
   Stop_Distance : constant := 45;
   Side_Distance : constant := 15;
   Turn_Distance : constant := 25;
   -- User measurements, 23 October 2026. Additional 5 cm on each side.
   Robot_Width : constant := 16;
   Robot_Length : constant := 23;
   Sensor_Offset : constant := 10;
   Lateral_Margin : constant := 5;
   function Valid (D : Distance) return Boolean;
   function Clear (D : Distance; Limit : Natural := Stop_Distance) return Boolean;
   function Filter (A, B, C : Distance) return Distance;
   function Forward_Safe (S : Snapshot) return Boolean;
   function Turn_Safe (S : Snapshot) return Boolean;
   function Corridor (Values : Distances) return Boolean;
   function Wide_Enough (Values : Distances; Span_Degrees : Positive)
                        return Boolean;
   function Select_Five (Values : Distances; S : Snapshot) return Choice;
   function Select_Seven (Values : Distances; S : Snapshot;
                          Previous_Center : Distance) return Choice;
end Adaptive_Policy;
