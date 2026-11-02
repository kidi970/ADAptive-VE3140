package body MicroBit.Buttons is
   Saved : Callback;
   function Subscribe (Handler : Callback) return Boolean is
   begin
      if Subscription_Accepted then Saved := Handler; end if;
      return Subscription_Accepted;
   end Subscribe;
   procedure Emit (Button : Button_Id; State : Button_State) is
   begin
      if Saved /= null then Saved (Button, State); end if;
   end Emit;
end MicroBit.Buttons;
