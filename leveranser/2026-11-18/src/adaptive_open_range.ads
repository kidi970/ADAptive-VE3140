with Adaptive_Policy;
with Adaptive_Range_Model;
package Adaptive_Open_Range with Pure is
   -- Completed pulses beyond the configured 200 cm working range are
   -- separate evidence, never a fabricated measured distance. The separate
   -- no-return windows must be checked on the installed HC-SR04 modules.
   Far_Pulse_Max_Us : constant := 26_000;
   No_Return_Min_Us : constant := 35_000;
   No_Return_Max_Us : constant := 42_000;
   Long_No_Return_Min_Us : constant := 55_000;
   Long_No_Return_Max_Us : constant := 65_000;
   function Classify (R : Adaptive_Range_Model.Echo_Result)
                      return Adaptive_Policy.Distance;
end Adaptive_Open_Range;
