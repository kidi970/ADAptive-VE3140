package body Adaptive_Range_Model is
   function Pulse_Distance (Pulse_Us : Natural) return Float is
     (Float (Pulse_Us) / 58.0);
   function Working_Range (D : Float) return Boolean is (D in 2.0 .. 200.0);
   function Divider_Output (Echo_Volts, Series_Ohms, Ground_Ohms : Float)
                            return Float is
   begin
      if Echo_Volts < 0.0 or Series_Ohms <= 0.0 or Ground_Ohms <= 0.0 then
         raise Constraint_Error with "Invalid voltage divider input";
      end if;
      return Echo_Volts * Ground_Ohms / (Series_Ohms + Ground_Ohms);
   end Divider_Output;
end Adaptive_Range_Model;
