package Adaptive_Policy with Pure is
   subtype Distance is Natural range 0 .. 401;
   Maximum_Measured_Distance : constant := 200;
   -- A completed over-range ECHO pulse is evidence for forward travel only.
   -- This marker is not a measured distance and never clears a turn corridor.
   Open_Range : constant Distance := 401;
   type Distances is array (Positive range <>) of Distance;
   type Choice is (Blocked, Straight, Right, Left);
   type Snapshot is record
      Front, Left, Right : Distance := 0;
   end record;
   Center : constant := 84;
   Stop_Distance : constant := 45; -- minimum individual corridor ray
   Forward_Stop_Distance : constant := 32;
   Corner_Stop_Distance : constant := 36;
   Side_Distance : constant := 15;
   Turn_Distance : constant := 20;
   -- Measured chassis dimensions. Trial clearance adds 3 cm per side.
   Robot_Width : constant := 16;
   Robot_Length : constant := 23;
   Sensor_Offset : constant := 10;
   Lateral_Margin : constant := 3;
   function Valid (D : Distance) return Boolean;
   function Clear (D : Distance; Limit : Natural := Stop_Distance) return Boolean;
   function Forward_Clear
     (D : Distance; Limit : Natural := Stop_Distance) return Boolean;
   function Filter (A, B, C : Distance) return Distance;
   function Forward_Safe (S : Snapshot; Front_Limit : Natural := Stop_Distance)
                          return Boolean;
   function Turn_Safe (S : Snapshot) return Boolean;
   function Corridor (Values : Distances) return Boolean;
   function Wide_Enough (Values : Distances; Span_Degrees : Positive)
                        return Boolean;
   function Select_Five (Values : Distances; S : Snapshot) return Choice;
   function Select_Seven (Values : Distances; S : Snapshot;
                          Previous_Center : Distance) return Choice;
end Adaptive_Policy;
