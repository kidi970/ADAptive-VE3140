package Adaptive_Range_Model with Pure is
   type Echo_Status is (Valid_Echo, No_Rise, No_Fall, Echo_Already_High,
                        Outside_Working_Range);
   type Echo_Result is record
      Status : Echo_Status := No_Rise;
      Pulse_Us : Natural := 0;
      Elapsed_Us : Natural := 0;
      Distance_CM : Float := 0.0;
      Legacy_Count_CM : Natural := 0;
   end record;
   function Pulse_Distance (Pulse_Us : Natural) return Float;
   function Working_Range (D : Float) return Boolean;
   -- Electrical calculations are conditional on the supplied voltages and
   -- resistor placement. They are not measurements of the installed wiring.
   function Divider_Output (Echo_Volts, Series_Ohms, Ground_Ohms : Float)
                            return Float;
end Adaptive_Range_Model;
