package body Adaptive_Scan_Policy is
   function Pivot_Side_Limit (Direction, Side : Choice) return Natural is
     (if Direction not in Left | Right then Turn_Distance
      elsif Direction = Side then Pivot_Target_Clearance
      else Pivot_Tail_Clearance);

   function Rotation_Clear (Guard : Snapshot; Direction : Choice;
                            Allow_Open : Boolean := False) return Boolean is
      function Ready (D : Distance; Limit : Natural) return Boolean is
        (if Allow_Open then Forward_Clear (D, Limit) else Clear (D, Limit));
   begin
      return Direction in Left | Right
        and then Ready (Guard.Front, Turn_Distance)
        and then Ready (Guard.Left, Pivot_Side_Limit (Direction, Left))
        and then Ready (Guard.Right, Pivot_Side_Limit (Direction, Right));
   end Rotation_Clear;

   function Near_Wall_Clear (Guard : Snapshot; Direction : Choice;
                             Wall_Limit : Natural := Wall_Release_Side_Distance) return Boolean is
      Tail_Side : constant Distance := (if Direction = Right then Guard.Left else Guard.Right);
      Exit_Side : constant Distance := (if Direction = Right then Guard.Right else Guard.Left);
   begin
      return Valid (Tail_Side)
        and then Tail_Side <= Wall_Limit
        and then Tail_Side < Exit_Side
        and then Rotation_Clear (Guard, Direction, Allow_Open => True);
   end Near_Wall_Clear;

   function Wall_Rotation_Clear (Guard : Snapshot) return Boolean is
     (Rotation_Clear (Guard, Left, Allow_Open => True)
      or else Rotation_Clear (Guard, Right, Allow_Open => True));

   function Wall_Guard_Clear (Guard : Snapshot) return Boolean is
     (Valid (Guard.Front) and then Wall_Rotation_Clear (Guard));

   function Wall_Profile (Guard : Snapshot; Right_Ray, Left_Ray : Distance)
                          return Boolean is
     (Wall_Guard_Clear (Guard) and then Guard.Front <= Wall_Probe_Range
      and then Clear (Right_Ray, Turn_Distance)
      and then Clear (Left_Ray, Turn_Distance)
      -- A broad near target produces similar returns at center and ±15°.
      and then abs (Integer (Right_Ray) - Integer (Guard.Front)) <= 7
      and then abs (Integer (Left_Ray) - Integer (Guard.Front)) <= 7);

   function Wall_Exit_Clear (Guard : Snapshot; Right_Ray, Left_Ray : Distance;
                             Direction : Choice) return Boolean is
      Wall_Ray : constant Distance := (if Direction = Right then Left_Ray else Right_Ray);
      Exit_Ray : constant Distance := (if Direction = Right then Right_Ray else Left_Ray);
      Wall_Side : constant Distance := (if Direction = Right then Guard.Left else Guard.Right);
      Exit_Side : constant Distance := (if Direction = Right then Guard.Right else Guard.Left);
      Near_Wall_Side : constant := 55;
      Exit_Side_Minimum : constant := 30;
   begin
      -- The wall can move out of the front diagonal into the fixed side beam
      -- as the car rotates. Either beam can provide the measured wall echo.
      return Rotation_Clear (Guard, Direction, Allow_Open => True)
        and then Forward_Clear (Wall_Ray, Turn_Distance)
        and then Forward_Clear (Exit_Ray, Corner_Stop_Distance)
        and then Forward_Clear (Exit_Side, Exit_Side_Minimum)
        and then (Wall_Ray < Exit_Ray or else Wall_Side < Exit_Side)
        and then (Wall_Ray <= Wall_Release_Distance or else Wall_Side <= Near_Wall_Side);
   end Wall_Exit_Clear;

   function Angles (Direction : Choice) return Angle_Pair is
   begin
      case Direction is
         when Right => return (34, 54);
         when Left => return (134, 114);
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
   function Acceptable (Pair : Distances; Guard : Snapshot; Direction : Choice;
                        Age_Ms : Natural) return Boolean is
     (Pair'Length = 2 and then Age_Ms <= Max_Pair_Age_Ms
      and then Rotation_Clear (Guard, Direction)
      and then Wide_Enough (Pair, Pair_Span_Degrees));
end Adaptive_Scan_Policy;
