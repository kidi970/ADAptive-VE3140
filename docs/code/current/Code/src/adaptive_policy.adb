with Ada.Numerics;
with Ada.Numerics.Elementary_Functions;
package body Adaptive_Policy is
   function Valid (D : Distance) return Boolean is (D in 2 .. 200);
   function Clear (D : Distance; Limit : Natural := Stop_Distance) return Boolean
     is (Valid (D) and then D > Limit);
   function Filter (A, B, C : Distance) return Distance is
      function Close (X, Y : Distance) return Boolean
        is (abs (Integer (X) - Integer (Y)) <= 15);
   begin
      -- Invalid samples veto motion. A short outlier must never be discarded
      -- in favour of two distant readings when an obstacle may be approaching.
      if not (Valid (A) and Valid (B) and Valid (C)) then
         return 0;
      elsif Close (A, B) or Close (A, C) or Close (B, C) then
         return Distance'Min (A, Distance'Min (B, C));
      else
         return 0;
      end if;
   end Filter;
   function Forward_Safe (S : Snapshot) return Boolean is
     (Clear (S.Front) and Clear (S.Left, Side_Distance)
      and Clear (S.Right, Side_Distance));
   function Turn_Safe (S : Snapshot) return Boolean is
     (Clear (S.Front, Turn_Distance) and Clear (S.Left, Turn_Distance)
      and Clear (S.Right, Turn_Distance));
   function Corridor (Values : Distances) return Boolean is
   begin
      if Values'Length < 2 then
         return False;
      end if;
      for D of Values loop
         if not Clear (D) then
            return False;
         end if;
      end loop;
      return True;
   end Corridor;
   function Wide_Enough (Values : Distances; Span_Degrees : Positive)
                        return Boolean is
      Nearest : Distance := Distance'Last;
      Width : Float;
   begin
      if not Corridor (Values) then return False; end if;
      for D of Values loop Nearest := Distance'Min (Nearest, D); end loop;
      Width := 2.0 * Float (Nearest) *
        Ada.Numerics.Elementary_Functions.Sin
          (Float (Span_Degrees) * Ada.Numerics.Pi / 360.0);
      return Width >= Float (Robot_Width + 2 * Lateral_Margin);
   end Wide_Enough;
   function Select_Five (Values : Distances; S : Snapshot) return Choice is
      R, L : Boolean;
   begin
      if Values'First /= 1 or Values'Last /= 5 then
         return Blocked;
      end if;
      if Wide_Enough (Values (2 .. 4), 24) and Forward_Safe (S) then
         return Straight;
      end if;
      if not Turn_Safe (S) then
         return Blocked;
      end if;
      R := Wide_Enough (Values (1 .. 2), 12);
      L := Wide_Enough (Values (4 .. 5), 12);
      if R and not L then return Right;
      elsif L and not R then return Left;
      elsif R and L then
         if Values (1) >= Values (5) then return Right;
         else return Left; end if;
      else return Blocked; end if;
   end Select_Five;
   function Select_Seven (Values : Distances; S : Snapshot;
                          Previous_Center : Distance) return Choice is
      R, L : Boolean;
   begin
      if Values'First /= 1 or Values'Last /= 7 then return Blocked; end if;
      if not Turn_Safe (S) or not Valid (Previous_Center)
        or not Valid (Values (4))
        or abs (Integer (Previous_Center) - Integer (Values (4))) > 15
      then return Blocked; end if;
      R := Wide_Enough (Values (1 .. 3), 20);
      L := Wide_Enough (Values (5 .. 7), 20);
      if R and not L then return Right;
      elsif L and not R then return Left;
      -- Two wide corridors: prefer the side with more verified clearance.
      elsif R and L then
         if S.Right >= S.Left then return Right;
         else return Left; end if;
      else return Blocked; end if;
   end Select_Seven;
end Adaptive_Policy;
