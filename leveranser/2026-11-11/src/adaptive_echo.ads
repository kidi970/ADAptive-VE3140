with nRF.GPIO;
with Adaptive_Range_Model;
generic
   Trigger_Pin, Echo_Pin : nRF.GPIO.GPIO_Point;
   Maximum_Distance_CM : Float := 200.0;
package Adaptive_Echo is
   -- Legacy count and clock-based pulse duration are captured together.
   function Read return Adaptive_Range_Model.Echo_Result;
end Adaptive_Echo;
