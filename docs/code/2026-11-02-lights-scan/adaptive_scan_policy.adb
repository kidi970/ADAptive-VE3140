package body Adaptive_Scan_Policy is
   function Angles (Direction : Choice) return Angle_Pair is
   begin
      case Direction is
         when Right => return (72, 60);
         when Left => return (96, 108);
         when others => return (Center, Center);
      end case;
   end Angles;
   function Preferred (S : Snapshot; Previous : Choice) return Choice is
   begin
      if S.Left > S.Right then return Left;
      elsif S.Right > S.Left then return Right;
      elsif Previous in Left | Right then return Previous;
      else return Right;
      end if;
   end Preferred;
   function Acceptable (Pair : Distances; Guard : Snapshot; Age_Ms : Natural)
                        return Boolean is
     (Pair'Length = 2 and then Age_Ms <= Max_Pair_Age_Ms
      and then Turn_Safe (Guard) and then Wide_Enough (Pair, 12));
end Adaptive_Scan_Policy;
