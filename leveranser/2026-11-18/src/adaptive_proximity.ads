with Ada.Real_Time;
with System;
with Adaptive_Policy;
package Adaptive_Proximity is
   protected State with Priority => System.Interrupt_Priority'Last is
      procedure Observe (Front : Adaptive_Policy.Distance);
      procedure Read (Front : out Adaptive_Policy.Distance; Fresh : out Boolean);
   private
      Value : Adaptive_Policy.Distance := 0;
      Stamp : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
   end State;
end Adaptive_Proximity;
