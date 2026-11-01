package MicroBit.Buttons is
   type Button_State is (Pressed, Released);
   type Button_Id is (Button_A, Button_B);
   type Callback is access procedure (Button : Button_Id; State : Button_State);
   Subscription_Accepted : Boolean := True;
   function Subscribe (Handler : Callback) return Boolean;
end MicroBit.Buttons;
