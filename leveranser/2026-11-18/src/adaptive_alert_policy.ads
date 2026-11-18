with Adaptive_Policy;
package Adaptive_Alert_Policy with Pure is
   -- Advisory sound only; these values never authorize movement.
   function Beep (Front : Adaptive_Policy.Distance; Phase_Ms : Natural;
                  Fresh, Armed, Stopped : Boolean) return Boolean;
end Adaptive_Alert_Policy;
