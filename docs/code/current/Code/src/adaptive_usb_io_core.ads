generic
   with procedure Configure_Input (Pin : Natural);
   with procedure Configure_Output (Pin : Natural);
   with procedure Write_Level (Pin : Natural; High : Boolean);
   with function Read_Level (Pin : Natural) return Boolean;
package Adaptive_USB_IO_Core is
   -- Physical nRF52833 pin indexes from the pinned micro:bit V2 board map.
   -- This adapter controls only the built-in centre pixel and buttons A/B.
   -- It has no external device objects and no callbacks during elaboration.
   procedure Initialize;
   procedure Center_On;
   procedure Center_Off;
   function Button_A_Pressed return Boolean;
   function Button_B_Pressed return Boolean;
end Adaptive_USB_IO_Core;
