package Adaptive_Lamp_Policy with Pure, SPARK_Mode is
   type Lamp_Mode is (Parked, Moving, Turning_Left, Turning_Right, Braking, Faulted);
   type Lamp_Outputs is record
      Brake, Left, Right : Boolean := False;
   end record;
   Blink_Period_Ms : constant := 1_000;
   function Outputs (Mode : Lamp_Mode; Phase_Ms : Natural) return Lamp_Outputs
     with Global => null,
       Post =>
         (Outputs'Result.Brake = (Mode in Parked | Braking | Faulted))
         and then (if Outputs'Result.Left then Mode in Turning_Left | Faulted)
         and then (if Outputs'Result.Right then Mode in Turning_Right | Faulted)
         and then (if Outputs'Result.Left and Outputs'Result.Right then Mode = Faulted)
         and then (if Mode = Moving then not Outputs'Result.Left and not Outputs'Result.Right);
end Adaptive_Lamp_Policy;
