package Adaptive_USB_IO is
   -- Standalone USB status adapter for micro:bit V2. Unlike MicroBit's broad
   -- parent package this unit does not instantiate any TWI/SPI/UART objects.
   -- Runtime/chip bring-up and physical GPIO behaviour remain unverified.
   procedure Initialize;
   procedure Center_On;
   procedure Center_Off;
   function Button_A_Pressed return Boolean;
   function Button_B_Pressed return Boolean;
end Adaptive_USB_IO;
