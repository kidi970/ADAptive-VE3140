package body Adaptive_USB_IO_Core is
   type Pins is array (Positive range <>) of Natural;
   Rows : constant Pins := (21, 22, 15, 24, 19);
   Columns : constant Pins := (28, 11, 31, 37, 30);
   Initialized : Boolean := False;
   procedure Require_Initialized is
   begin
      if not Initialized then raise Program_Error with "USB GPIO not initialized"; end if;
   end Require_Initialized;
   procedure Initialize is
   begin
      if Initialized then return; end if;
      -- Disable every row before changing any column direction. Preload
      -- output latches before switching the corresponding pins to outputs.
      for Pin of Rows loop
         Write_Level (Pin, False); Configure_Output (Pin);
      end loop;
      for Pin of Columns loop
         Write_Level (Pin, True); Configure_Output (Pin);
      end loop;
      Configure_Input (14); Configure_Input (23);
      Initialized := True;
   end Initialize;
   procedure Center_On is
   begin
      Require_Initialized;
      Write_Level (15, False);
      Write_Level (31, False);
      Write_Level (15, True);
   end Center_On;
   procedure Center_Off is
   begin
      Require_Initialized;
      Write_Level (15, False);
      Write_Level (31, True);
   end Center_Off;
   function Button_A_Pressed return Boolean is
   begin
      Require_Initialized; return not Read_Level (14);
   end Button_A_Pressed;
   function Button_B_Pressed return Boolean is
   begin
      Require_Initialized; return not Read_Level (23);
   end Button_B_Pressed;
end Adaptive_USB_IO_Core;
