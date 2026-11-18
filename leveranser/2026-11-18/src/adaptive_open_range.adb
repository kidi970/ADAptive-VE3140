with Adaptive_Policy; use Adaptive_Policy;
with Adaptive_Range_Model; use Adaptive_Range_Model;
package body Adaptive_Open_Range is
   function Classify (R : Echo_Result) return Distance is
      D : constant Float := Pulse_Distance (R.Pulse_Us);
   begin
      -- Status is set to these two cases only after both ECHO edges.
      -- A missing edge, pre-existing high level, or expired deadline is
      -- unknown even if the record contains a long pulse duration.
      if R.Status = Valid_Echo and then Working_Range (D) then
         return Distance (Float'Floor (D));
      elsif R.Status = Outside_Working_Range then
         if (R.Pulse_Us > Maximum_Measured_Distance * 58
             and then R.Pulse_Us <= Far_Pulse_Max_Us)
           or else R.Pulse_Us in No_Return_Min_Us .. No_Return_Max_Us
           or else R.Pulse_Us in Long_No_Return_Min_Us .. Long_No_Return_Max_Us
         then
            return Open_Range;
         end if;
      end if;
      return 0;
   end Classify;
end Adaptive_Open_Range;
