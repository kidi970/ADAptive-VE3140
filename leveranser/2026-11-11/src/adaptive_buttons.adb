with MicroBit.Buttons;

package body Adaptive_Buttons is

   use type MicroBit.Buttons.Button_State;

   A_Pending : Boolean := False
   with Atomic;
   B_Pending : Boolean := False
   with Atomic;

   procedure On_Button
     (Button : MicroBit.Buttons.Button_Id;
      State  : MicroBit.Buttons.Button_State) is
   begin
      if State = MicroBit.Buttons.Pressed then
         case Button is
            when MicroBit.Buttons.Button_A =>
               A_Pending := True;

            when MicroBit.Buttons.Button_B =>
               B_Pending := True;

            when others                    =>
               null;
         end case;
      end if;
   end On_Button;

   procedure Initialize is
   begin
      if not MicroBit.Buttons.Subscribe (On_Button'Access) then
         raise Program_Error with "Button registration failed";
      end if;
   end Initialize;

   function Take_A return Boolean is
      Result : constant Boolean := A_Pending;
   begin
      A_Pending := False;
      return Result;
   end Take_A;

   function Take_B return Boolean is
      Result : constant Boolean := B_Pending;
   begin
      B_Pending := False;
      return Result;
   end Take_B;

end Adaptive_Buttons;
