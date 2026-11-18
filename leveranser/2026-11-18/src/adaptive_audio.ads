package Adaptive_Audio is
   -- Sole PWM0 / on-board speaker owner. No edge pin, IRQ or blocking wait.
   procedure Set_Tone (Enabled : Boolean);
end Adaptive_Audio;
