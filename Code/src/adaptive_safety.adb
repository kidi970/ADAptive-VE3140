with MicroBit.Buttons;
with Adaptive_Errors;
package body Adaptive_Safety is
   use type MicroBit.Buttons.Button_State;
   use type MicroBit.Buttons.Button_Id;
   procedure Request_Stop is
   begin
      Stop_Requested := True;
   end Request_Stop;
   procedure Request_Start is
   begin
      if not Stop_Requested then Start_Requested := True; end if;
   end Request_Start;
   procedure On_Button (Button : MicroBit.Buttons.Button_Id;
                        State : MicroBit.Buttons.Button_State) is
   begin
      if State = MicroBit.Buttons.Pressed then
         if Button = MicroBit.Buttons.Button_B then Request_Stop;
         elsif Button = MicroBit.Buttons.Button_A then Request_Start;
         end if;
      end if;
   end On_Button;
   procedure Initialize is
   begin
      if not MicroBit.Buttons.Subscribe (On_Button'Access) then
         raise Adaptive_Errors.Safety_Setup_Error
           with "Stop button registration failed";
      end if;
   end Initialize;
end Adaptive_Safety;
