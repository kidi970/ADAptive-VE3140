with Ada.Numerics.Elementary_Functions;
with Adaptive_Range_Model; use Adaptive_Range_Model;
package body Adaptive_Bench_Model is
   function Finite (Value : Float) return Boolean is
     (Value >= -Float'Last and then Value <= Float'Last);
   function Summarize (Values : Readings) return Statistics is
      S : Statistics;
      D : array (1 .. 3) of Float;
      Temp, Sum_Squares : Float;
   begin
      for I in Values'Range loop
         if Values (I).Status = Valid_Echo
           and then Working_Range (Values (I).Distance_CM)
         then S.Valid_Count := S.Valid_Count + 1; end if;
         D (I) := Values (I).Distance_CM;
      end loop;
      S.Valid_Fraction := Float (S.Valid_Count) / Float (Values'Length);
      -- A missing echo vetoes this window. No last-good or zero imputation.
      if S.Valid_Count /= 3 then return S; end if;
      for I in 1 .. 2 loop
         for J in I + 1 .. 3 loop
            if D (I) > D (J) then
               Temp := D (I); D (I) := D (J); D (J) := Temp;
            end if;
         end loop;
      end loop;
      S.Mean := (D (1) + D (2) + D (3)) / 3.0;
      S.Median := D (2); S.Minimum := D (1);
      S.Spread := D (3) - D (1);
      Sum_Squares := 0.0;
      for V of D loop Sum_Squares := Sum_Squares + (V - S.Mean) ** 2; end loop;
      S.Sample_SD := Ada.Numerics.Elementary_Functions.Sqrt (Sum_Squares / 2.0);
      S.Stable := S.Spread <= 15.0;
      return S;
   end Summarize;
   function Assess (Front, Left, Right : Statistics) return Indication is
      function Usable (S : Statistics) return Boolean is
        (S.Valid_Count = 3 and then S.Valid_Fraction = 1.0 and then S.Stable
         and then Working_Range (S.Minimum) and then Working_Range (S.Mean)
         and then Working_Range (S.Median)
         and then S.Spread in 0.0 .. 15.0
         and then S.Sample_SD in 0.0 .. 200.0);
   begin
      if not Usable (Front) or else not Usable (Left) or else not Usable (Right)
      then return Unknown;
      elsif Front.Minimum <= 45.0 or Left.Minimum <= 15.0
        or Right.Minimum <= 15.0
      then return Stop;
      elsif Front.Minimum <= 60.0 or Left.Minimum <= 30.0
        or Right.Minimum <= 30.0
      then return Caution;
      else return Clear; end if;
   end Assess;
   function LED_Current_MA (Supply_V, Forward_V, Resistance_Ohm : Float)
                           return Float is
      Current : Float;
   begin
      if not Finite (Supply_V) or else not Finite (Forward_V)
        or else not Finite (Resistance_Ohm)
        or else Supply_V < 0.0 or else Forward_V < 0.0
        or else Resistance_Ohm <= 0.0
      then
         raise Constraint_Error with "Invalid LED circuit input";
      end if;
      if Supply_V <= Forward_V then return 0.0; end if;
      Current := ((Supply_V - Forward_V) / Resistance_Ohm) * 1000.0;
      if not Finite (Current) then
         raise Constraint_Error with "LED circuit result out of range";
      end if;
      return Current;
   end LED_Current_MA;
   function Divider_Bounds
     (Supply_Low, Supply_High, Series_Ohm, Ground_Ohm, Tolerance : Float)
      return Voltage_Bounds is
      Scale, Series, Ground : Float;
   begin
      if not Finite (Supply_Low) or else not Finite (Supply_High)
        or else not Finite (Series_Ohm) or else not Finite (Ground_Ohm)
        or else not Finite (Tolerance)
        or else Supply_Low < 0.0 or else Supply_High < Supply_Low
        or else Series_Ohm <= 0.0 or else Ground_Ohm <= 0.0
        or else Tolerance < 0.0 or else Tolerance >= 1.0
      then raise Constraint_Error with "Invalid divider bounds"; end if;
      -- The ratio is invariant to a common scale. Normalize before tolerance
      -- arithmetic so huge finite resistor values cannot overflow the sum.
      Scale := Float'Max (Series_Ohm, Ground_Ohm);
      Series := Series_Ohm / Scale; Ground := Ground_Ohm / Scale;
      return
        (Low => Supply_Low * ((Ground * (1.0 - Tolerance)) /
          (Series * (1.0 + Tolerance) + Ground * (1.0 - Tolerance))),
         High => Supply_High * ((Ground * (1.0 + Tolerance)) /
          (Series * (1.0 - Tolerance) + Ground * (1.0 + Tolerance))));
   end Divider_Bounds;
end Adaptive_Bench_Model;
