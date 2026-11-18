with Adaptive_Policy;

--  Experimental, host-tested mathematics. This package has no hardware calls
--  and does not replace the production navigation gates. Sampled openings do
--  not prove that the unsampled area or the swept turning path is clear.
package Adaptive_Offline_Model with Pure is
   type Sample_Status is (Measured, Timed_Out, Missing, Rejected);
   type Sample is record
      Status : Sample_Status := Missing;
      Distance_M : Float := 0.0;
      Stamp_Ms : Natural := 0;
   end record;
   type Samples is array (Positive range <>) of Sample;
   type Guard_Samples is record
      Front, Left, Right : Sample;
   end record;

   function Usable (S : Sample; Now_Ms, Max_Age_Ms : Natural) return Boolean;
   type Statistics is record
      Total, Valid_Count : Natural := 0;
      Valid_Fraction, Minimum_M, Mean_M, Population_SD_M : Float := 0.0;
   end record;
   --  Invalid readings are counted explicitly. Descriptive statistics never
   --  constitute clearance: the planner below requires every supplied ray.
   function Summarize (Values : Samples; Now_Ms, Max_Age_Ms : Natural)
                       return Statistics;

   type Stop_Parameters is record
      Speed_M_Per_S, Latency_S, Deceleration_M_Per_S2, Margin_M : Float := 0.0;
   end record;
   type Model_Value is record
      Valid : Boolean := False;
      Value : Float := 0.0;
   end record;
   --  d = v*t + v**2/(2*a) + margin. The caller supplies an independently
   --  justified speed upper bound, latency upper bound and deceleration lower
   --  bound; PWM is not speed. Domain: 0<=v<=20, 0<=t<=60, .001<=a<=100,
   --  0<=margin<=1000 (SI). Bounds prevent overflow; no input is clamped.
   function Stop_Clearance (P : Stop_Parameters) return Model_Value;

   type Angle_Calibration is record
      Established : Boolean := False;
      Center_Command : Float := 84.0;
      Degrees_Per_Command : Float := 1.0;
      Mount_Yaw_Degrees, Offset_X_M, Offset_Y_M : Float := 0.0;
   end record;
   type Point is record
      Valid : Boolean := False;
      X_M, Y_M : Float := 0.0;
   end record;
   --  x points forwards; y points left. Command angles acquire geometric
   --  meaning only through explicit calibration, including its signed slope.
   function Ray_Point (S : Sample; Servo_Command : Float;
                       Calibration : Angle_Calibration;
                       Now_Ms, Max_Age_Ms : Natural) return Point;
   --  Chord approximation at the nearest measured range, with a supplied
   --  physical angular span. It is not a swept-volume collision certificate.
   function Sampled_Opening (Nearest_Range_M, Angular_Span_Degrees : Float)
                             return Model_Value;

   type Decision is record
      Direction : Adaptive_Policy.Choice := Adaptive_Policy.Blocked;
      Generation, Oldest_Ms, Issued_Ms : Natural := 0;
      Consumed : Boolean := False;
   end record;
   type Consumption_State is private;
   --  Offline replay of the existing 1/5/7-point policy. All supplied scan
   --  and guard samples must be fresh and valid. Existing absolute distance
   --  and width gates still apply. Stop_Clearance can only tighten them.
   --  Hysteresis ranks already eligible side candidates; ties choose Right.
   --  Seven points also require the independently acquired previous center.
   function Plan (Scan : Samples; Guard : Guard_Samples;
                  Previous_Center : Sample; Previous : Adaptive_Policy.Choice;
                  Stop : Stop_Parameters; Now_Ms, Max_Age_Ms, Generation : Natural;
                  Hysteresis_M : Float := 0.05) return Decision;
   --  A decision is a single-use observation token, even if a consume attempt
   --  is rejected. A new generation needs newly acquired data, not a copied
   --  old direction. This models authorization only; it never drives motors.
   --  Keep one state for the whole offline sequence: copying a Decision cannot
   --  create another authorization. Even a larger generation needs every used
   --  sample timestamp after the previously accepted decision's issue time.
   --  Timestamps must describe actual acquisitions in one monotonic clock;
   --  the caller must not re-stamp old values as new measurements.
   procedure Consume (D : in out Decision; State : in out Consumption_State;
                      Now_Ms, Max_Age_Ms,
                      Observation_Generation : Natural; Allowed : out Boolean);
private
   type Consumption_State is record
      Last_Generation, Last_Accepted_Issued_Ms : Natural := 0;
      Has_Accepted : Boolean := False;
   end record;
end Adaptive_Offline_Model;
