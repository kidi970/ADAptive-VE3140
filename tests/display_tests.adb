with Ada.Text_IO; use Ada.Text_IO;
with Adaptive_Display;
with MicroBit.DisplayRT;
with MicroBit.I2C; use MicroBit.I2C;
procedure Display_Tests is
   Checks : Natural := 0;
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if not Condition then raise Program_Error with Name; end if;
      Checks := Checks + 1;
   end Check;
begin
   Check (not Adaptive_Display.Available, "OLED not ready before startup");
   Adaptive_Display.Show_Status ("STATUS: STOP");
   Check (Calls = 0, "uninitialized OLED never uses bus");
   Adaptive_Display.Initialize;
   Check (Adaptive_Display.Available and Calls > 1, "successful OLED startup");
   Reset_Trace;
   Adaptive_Display.Show_Status ("STATUS: STOP");
   Check (Calls > 1, "healthy OLED writes status");
   for I in 1 .. Calls loop Check (Trace (I).Timeout = 20, "bounded OLED transaction"); end loop;
   Reset_Trace; Fail_At := 1;
   Adaptive_Display.Show_Front ("FRONT: 10 CM");
   Check (not Adaptive_Display.Available and Calls = 1, "first fault opens circuit breaker");
   Adaptive_Display.Show_Status ("STATUS: STOP");
   Adaptive_Display.Show_Front ("FRONT: 99 CM");
   Adaptive_Display.Initialize;
   Check (Calls = 1, "failed OLED never creates retry storm");
   Adaptive_Display.Show_Direction ('S');
   Check (MicroBit.DisplayRT.Pixels (0, 0) and MicroBit.DisplayRT.Pixels (2, 2),
          "local stop symbol survives missing OLED");
   Adaptive_Display.Show_Direction ('L');
   Check (MicroBit.DisplayRT.Pixels (0, 2) and MicroBit.DisplayRT.Pixels (4, 2),
          "local arrow independent from external bus");
   Put_Line ("PASS" & Natural'Image (Checks) & " display checks (mock I2C)");
end Display_Tests;
