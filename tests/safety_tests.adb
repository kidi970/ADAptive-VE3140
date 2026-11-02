with Ada.Text_IO; use Ada.Text_IO;
with Adaptive_Safety; use Adaptive_Safety;
with MicroBit.Buttons; use MicroBit.Buttons;
procedure Safety_Tests is
   Checks : Natural := 0;
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if not Condition then raise Program_Error with Name; end if;
      Checks := Checks + 1;
   end Check;
begin
   Adaptive_Safety.Initialize;
   Check (not Start_Requested and not Stop_Requested, "boot is unarmed");
   Emit (Button_A, Released);
   Check (not Start_Requested, "release cannot arm");
   Emit (Button_A, Pressed);
   Check (Start_Requested and not Stop_Requested, "A requests start");
   Emit (Button_B, Released);
   Check (not Stop_Requested, "release cannot stop");
   Emit (Button_B, Pressed);
   Check (Stop_Requested, "B latches stop");
   Start_Requested := False; -- isolated fixture, not a firmware reset API
   Emit (Button_A, Pressed);
   Check (not Start_Requested and Stop_Requested, "A cannot override a latched stop");
   Put_Line ("PASS" & Natural'Image (Checks) & " safety button checks");
end Safety_Tests;
