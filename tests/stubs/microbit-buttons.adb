package body MicroBit.Buttons is
   function Subscribe (Handler : Callback) return Boolean is
      pragma Unreferenced (Handler);
   begin
      return Subscription_Accepted;
   end Subscribe;
end MicroBit.Buttons;
