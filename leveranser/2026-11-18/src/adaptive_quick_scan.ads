with Adaptive_Policy; use Adaptive_Policy;
with Adaptive_Scan_Policy;
generic
   with procedure Recenter;
   with procedure Point (Angle : Natural; Value : out Distance;
                         Sample_Started_Ms : out Natural);
   with function Read_Guard return Snapshot;
   with function Now_Ms return Natural;
   with function Stop_Requested return Boolean;
   with procedure Report_Reject
     (Direction : Choice; Reason : Adaptive_Scan_Policy.Scan_Rejection) is null;
   Front_Limit : Positive := Stop_Distance;
   Wall_Pivot_Enabled : Boolean := False;
package Adaptive_Quick_Scan is
   type Scan_Result is record
      Direction : Choice := Blocked;
      Points : Natural range 0 .. 7 := 0;
      Wall_Pivot : Boolean := False;
      Wall_Exit : Boolean := False;
      Pivot_Guard : Snapshot;
      Expired_Pairs : Natural range 0 .. 2 := 0;
      Oldest_Pair_Ms : Natural := 0;
   end record;
   -- Stationary first-feasible search: one near-wall exit ray, up to two wall
   -- rays and up to four corridor rays. Never drives a motor.
   function Find (Previous : Choice := Blocked;
                  Allow_Straight : Boolean := True;
                  Continue_Wall : Choice := Blocked;
                  Try_Wall : Boolean := True;
                  Avoid_Side : Choice := Blocked) return Scan_Result;
end Adaptive_Quick_Scan;
