package Adaptive_Safety is
   Start_Requested : Boolean := False
     with Atomic, Export, External_Name => "adaptive_start_requested";
   Stop_Requested : Boolean := False
     with Atomic, Export, External_Name => "adaptive_stop_requested";
   Motion_Commanded : Boolean := False
     with Atomic, Export, External_Name => "adaptive_motion_commanded";
   Motor_Stop_Acknowledged : Boolean := False
     with Atomic, Export, External_Name => "adaptive_motor_stop_acknowledged";
   -- Bus acknowledgement is distinct from physical wheel standstill.
   procedure Request_Stop;
   procedure Request_Start;
   procedure Initialize;
end Adaptive_Safety;
