package Adaptive_Lights is
   -- micro:bit edge pins, not Raspberry Pi pin numbers:
   -- P0: two red LEDs (one 1 kohm resistor per LED); P12: left; P16: right.
   procedure Initialize;
   function Failed return Boolean;
end Adaptive_Lights;
