with Ada.Text_IO; use Ada.Text_IO;
with Adaptive_Range_Model; use Adaptive_Range_Model;
procedure Range_Tests is
   Checks : Natural := 0;
   procedure Check (Condition : Boolean; Name : String) is
   begin
      Checks := Checks + 1;
      if not Condition then raise Program_Error with Name; end if;
   end Check;
   procedure Reject (V, Rs, Rg : Float) is
      Result : Float;
   begin
      Result := Divider_Output (V, Rs, Rg);
      Check (False, "invalid divider accepted" & Float'Image (Result));
   exception
      when Constraint_Error => Check (True, "invalid divider rejected");
   end Reject;
   R : Echo_Result;
   Distances : constant array (Positive range <>) of Natural :=
     (2, 20, 30, 45, 60, 100, 150, 200);
begin
   Check (R.Status /= Valid_Echo and R.Distance_CM = 0.0, "default unknown");
   Check (Pulse_Distance (0) = 0.0, "zero pulse");
   for Cm of Distances loop
      Check (abs (Pulse_Distance (Cm * 58) - Float (Cm)) < 0.001, "pulse conversion");
   end loop;
   Check (not Working_Range (1.999), "below lower bound");
   Check (Working_Range (2.0), "lower bound");
   Check (Working_Range (200.0), "upper bound");
   Check (not Working_Range (200.001), "above upper bound");
   Check (not Working_Range (0.0), "zero unknown");
   Check (abs (Divider_Output (5.0, 1000.0, 1200.0) - 2.727273) < 0.00001,
          "1k series, 1.2k ground");
   Check (Divider_Output (5.0, 1200.0, 1000.0) < 0.7 * 3.3,
          "reversed divider below nominal VIH");
   Check (Divider_Output (5.0, 1000.0, 1200.0) > 0.7 * 3.3,
          "intended divider above nominal VIH");
   Check (Divider_Output (0.0, 1000.0, 1200.0) = 0.0, "zero input voltage");
   Reject (-1.0, 1000.0, 1200.0);
   Reject (5.0, 0.0, 1200.0);
   Reject (5.0, 1000.0, 0.0);
   Reject (5.0, -1.0, 1200.0);
   Reject (5.0, 1000.0, -1.0);
   Put_Line ("PASS range model:" & Natural'Image (Checks) & " checks");
end Range_Tests;
