with nRF.GPIO;
with Adaptive_Range_Model;
generic
   Trigger_Pin, Echo_Pin : nRF.GPIO.GPIO_Point;
package Adaptive_Echo is
   -- Diagnostic acquisition: the production driver's policy is unchanged.
   -- Legacy count and clock-based pulse duration are captured together.
   function Read return Adaptive_Range_Model.Echo_Result;
end Adaptive_Echo;
