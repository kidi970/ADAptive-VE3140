package Adaptive_Display is
   procedure Initialize;
   function Available return Boolean;
   procedure Show_Direction (Direction : Character);
   procedure Show_Status (Message : String);
   procedure Show_Front (Message : String);
end Adaptive_Display;
