with Adaptive_Range_Model;
package Adaptive_Bench_Model with Pure is
   type Readings is array (1 .. 3) of Adaptive_Range_Model.Echo_Result;
   type Statistics is record
      Valid_Count : Natural range 0 .. 3 := 0;
      Valid_Fraction : Float := 0.0;
      Stable : Boolean := False;
      Mean, Median, Minimum, Spread, Sample_SD : Float := 0.0;
   end record;
   function Summarize (Values : Readings) return Statistics;
   type Indication is (Unknown, Stop, Caution, Clear);
   function Assess (Front, Left, Right : Statistics) return Indication;
   -- Bench indications reuse conservative prototype thresholds. They do not
   -- certify stopping distance and never command a motor.
   function LED_Current_MA (Supply_V, Forward_V, Resistance_Ohm : Float)
                           return Float;
   type Voltage_Bounds is record
      Low, High : Float;
   end record;
   function Divider_Bounds
     (Supply_Low, Supply_High, Series_Ohm, Ground_Ohm, Tolerance : Float)
      return Voltage_Bounds;
end Adaptive_Bench_Model;
