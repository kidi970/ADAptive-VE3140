package Adaptive_Lights is
   -- micro:bit edge pins, not Raspberry Pi pin numbers:
   -- P0: two red LEDs (one 1 kohm resistor per LED); P12: left; P16: right.
   -- Temporary powerbank-load experiment, matching commit 7cf0071: keep all
   -- external lights on in every mode. False restores normal lamp signals.
   Powerbank_LED_Test : constant Boolean := False;
   procedure Initialize;
   function Failed return Boolean;
end Adaptive_Lights;
