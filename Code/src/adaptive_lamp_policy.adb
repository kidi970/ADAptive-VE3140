package body Adaptive_Lamp_Policy with SPARK_Mode is
   function Outputs (Mode : Lamp_Mode; Phase_Ms : Natural) return Lamp_Outputs is
      Blink : constant Boolean := Phase_Ms mod Blink_Period_Ms < 500;
   begin
      case Mode is
         when Parked | Braking => return (True, False, False);
         when Moving => return (False, False, False);
         when Turning_Left => return (False, Blink, False);
         when Turning_Right => return (False, False, Blink);
         when Faulted => return (True, Blink, Blink);
      end case;
   end Outputs;
end Adaptive_Lamp_Policy;
