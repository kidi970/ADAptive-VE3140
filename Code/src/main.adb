with MicroBit.Console; use MicroBit.Console;
with MicroBit.DisplayRT;
with MicroBit.DisplayRT.Symbols;
with MicroBit.Buttons; use MicroBit.Buttons;
use MicroBit;
-- USN PROJECT TEMPLATE INTELLIGENT REAL-TIME SYSTEMS
-- Project name: [ADAptive]
-- Project members: [Jacob Hellumsand Utengen, Nicolay Olafsen]
procedure Main is
begin
   Put_Line ("MY ADAptive BUTTON BUILD IS RUNNING");

   loop
      if MicroBit.Buttons.State (Button_A) = Pressed then
         MicroBit.DisplayRT.Display ('A');
         Put_Line ("Pressed A");

      elsif MicroBit.Buttons.State (Button_B) = Pressed then
         MicroBit.DisplayRT.Display ('B');
         Put_Line ("Pressed B");

      elsif MicroBit.Buttons.State (Logo) = Pressed then
         MicroBit.DisplayRT.Symbols.Heart;
         Put_Line ("Pressed L");

      else
         MicroBit.DisplayRT.Clear;
      end if;
   end loop;
end Main;
