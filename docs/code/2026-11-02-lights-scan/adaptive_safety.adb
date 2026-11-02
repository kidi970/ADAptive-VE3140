with MicroBit.Buttons;
with Adaptive_Errors;
with Adaptive_Lamp_Control;
with Adaptive_Lamp_Policy;
package body Adaptive_Safety is
   use type MicroBit.Buttons.Button_State;
   use type MicroBit.Buttons.Button_Id;
   procedure Request_Stop is
   begin
      Stop_Requested := True;
      Adaptive_Lamp_Control.State.Set_Mode (Adaptive_Lamp_Policy.Braking);
   end Request_Stop;
   procedure On_Button (Button : MicroBit.Buttons.Button_Id;
                        State : MicroBit.Buttons.Button_State) is
   begin
      if Button = MicroBit.Buttons.Button_B
        and then State = MicroBit.Buttons.Pressed
      then Request_Stop; end if;
   end On_Button;
   procedure Initialize is
   begin
      if not MicroBit.Buttons.Subscribe (On_Button'Access) then
         raise Adaptive_Errors.Safety_Setup_Error
           with "Stop button registration failed";
      end if;
   end Initialize;
end Adaptive_Safety;
