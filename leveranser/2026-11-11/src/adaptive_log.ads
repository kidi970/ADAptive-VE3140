package Adaptive_Log is
   -- Uses the on-board UART to the USB interface at 115200 baud. It never
   -- initializes an external peripheral. Calls are for the foreground only.
   -- A failed logger stays disabled until firmware restart.
   procedure Put_Line (Message : String);
   function Failed return Boolean;
end Adaptive_Log;
