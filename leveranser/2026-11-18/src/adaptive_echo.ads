with nRF.GPIO;
with Adaptive_Range_Model;
generic
   Trigger_Pin, Echo_Pin : nRF.GPIO.GPIO_Point;
   Fall_Timeout_Ms : Positive := 23;
package Adaptive_Echo is
   -- Default preserves the historical diagnostic. Open-space acquisition
   -- explicitly waits longer for a completed no-return pulse.
   -- Legacy count and clock-based pulse duration are captured together.
   function Read return Adaptive_Range_Model.Echo_Result;
end Adaptive_Echo;
