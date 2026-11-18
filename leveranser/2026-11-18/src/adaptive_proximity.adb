with Ada.Real_Time; use Ada.Real_Time;
package body Adaptive_Proximity is
   protected body State is
      procedure Observe (Front : Adaptive_Policy.Distance) is
      begin
         Value := Front;
         Stamp := Clock;
      end Observe;
      procedure Read (Front : out Adaptive_Policy.Distance; Fresh : out Boolean) is
      begin
         Front := Value;
         Fresh := Stamp /= Time_First and then Clock - Stamp <= Milliseconds (1_000);
      end Read;
   end State;
end Adaptive_Proximity;
