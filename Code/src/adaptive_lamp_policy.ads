package Adaptive_Lamp_Policy with Pure is
   type Lamp_Mode is (Parked, Moving, Turning_Left, Turning_Right, Braking, Faulted);
   type Lamp_Outputs is record
      Brake, Left, Right : Boolean := False;
   end record;
   Blink_Period_Ms : constant := 1_000;
   function Outputs (Mode : Lamp_Mode; Phase_Ms : Natural) return Lamp_Outputs;
end Adaptive_Lamp_Policy;
