with Adaptive_Sensors; use Adaptive_Sensors;
with Adaptive_Policy; use Adaptive_Policy;
with Adaptive_Log; use Adaptive_Log;
procedure Sensor_Nfc_Check is
   D : Distance;
begin
   Put_Line ("NFC SENSOR CHECK BEGIN; NO MOTOR OR SERVO DRIVER LINKED");
   Initialize;
   for Cycle in 1 .. 15 loop
      for Which in Sensor loop
         D := Filtered (Which);
         Put_Line ("CHECK" & Integer'Image (Cycle) & " " & Sensor'Image (Which)
                   & " FILTER" & Distance'Image (D));
      end loop;
   end loop;
   Put_Line ("NFC SENSOR CHECK DONE,135");
   loop delay 1.0; end loop;
exception
   when others =>
      Put_Line ("NFC SENSOR CHECK FAULT");
      loop delay 1.0; end loop;
end Sensor_Nfc_Check;
