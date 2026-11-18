with nRF.GPIO; use nRF.GPIO;
with Adaptive_USB_IO_Core;
package body Adaptive_USB_IO is
   procedure Configure_Input (Pin : Natural) is
      Point : GPIO_Point := (Pin => GPIO_Pin_Index (Pin));
   begin
      Point.Configure_IO
        ((Mode => Mode_In, Resistors => No_Pull,
          Input_Buffer => Input_Buffer_Connect,
          Sense => Sense_Disabled, Drive => Drive_S0S1));
   end Configure_Input;
   procedure Configure_Output (Pin : Natural) is
      Point : GPIO_Point := (Pin => GPIO_Pin_Index (Pin));
   begin
      Point.Configure_IO
        ((Mode => Mode_Out, Resistors => No_Pull,
          Input_Buffer => Input_Buffer_Disconnect,
          Sense => Sense_Disabled, Drive => Drive_S0S1));
   end Configure_Output;
   procedure Write_Level (Pin : Natural; High : Boolean) is
      Point : GPIO_Point := (Pin => GPIO_Pin_Index (Pin));
   begin
      if High then Point.Set; else Point.Clear; end if;
   end Write_Level;
   function Read_Level (Pin : Natural) return Boolean is
      Point : GPIO_Point := (Pin => GPIO_Pin_Index (Pin));
   begin
      return Point.Set;
   end Read_Level;
   package Core is new Adaptive_USB_IO_Core
     (Configure_Input, Configure_Output, Write_Level, Read_Level);
   procedure Initialize is begin Core.Initialize; end Initialize;
   procedure Center_On is begin Core.Center_On; end Center_On;
   procedure Center_Off is begin Core.Center_Off; end Center_Off;
   function Button_A_Pressed return Boolean is (Core.Button_A_Pressed);
   function Button_B_Pressed return Boolean is (Core.Button_B_Pressed);
end Adaptive_USB_IO;
