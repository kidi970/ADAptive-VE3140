package Adaptive_Safety is
   Stop_Requested : Boolean := False
     with Atomic, Export, External_Name => "adaptive_stop_requested";
   Motion_Commanded : Boolean := False
     with Atomic, Export, External_Name => "adaptive_motion_commanded";
   procedure Initialize;
end Adaptive_Safety;
