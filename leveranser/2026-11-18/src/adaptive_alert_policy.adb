with Adaptive_Policy; use Adaptive_Policy;
package body Adaptive_Alert_Policy is
   function Beep (Front : Distance; Phase_Ms : Natural;
                  Fresh, Armed, Stopped : Boolean) return Boolean is
      Period : Positive;
   begin
      if not Fresh or else not Armed or else Stopped
        or else not Valid (Front) or else Front > 80
      then return False; end if;
      Period := (if Front <= 25 then 200
                 elsif Front <= Stop_Distance then 500 else 1_000);
      return Phase_Ms mod Period < 100;
   end Beep;
end Adaptive_Alert_Policy;
