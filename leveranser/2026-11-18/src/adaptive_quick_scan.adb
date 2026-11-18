with Adaptive_Scan_Policy; use Adaptive_Scan_Policy;
package body Adaptive_Quick_Scan is
   function Find (Previous : Choice := Blocked;
                  Allow_Straight : Boolean := True;
                  Continue_Wall : Choice := Blocked;
                  Try_Wall : Boolean := True;
                  Avoid_Side : Choice := Blocked) return Scan_Result is
      R : Scan_Result;
      S : Snapshot;
      First : Choice;
      type Direction_Pair is array (1 .. 2) of Choice;
      Order : Direction_Pair;
      Pair : Distances (1 .. 2);
      Stamp, Oldest, Current : Natural;
      Wall_Right, Wall_Left, Exit_Ray : Distance;
      Wall_First, Wall_Second : Natural;
      Following_Wall : constant Boolean := Continue_Wall in Left | Right;
      Side_Closing : constant Boolean := Avoid_Side in Left | Right;
      Straight_Allowed : constant Boolean := Allow_Straight and then not Side_Closing;
      Try_Oblique_Wall : constant Boolean := Following_Wall or else not Straight_Allowed;
      Wall_Limit : constant Natural :=
        (if Side_Closing then Side_Approach_Distance else Wall_Release_Side_Distance);
      function First_Side return Choice is
        (case Avoid_Side is
            when Left => Right,
            when Right => Left,
            when others => (if Following_Wall then Continue_Wall else Preferred (S, Previous)));
      function Wall_Choice return Choice is
         Preferred_Side : constant Choice := First_Side;
         Other_Side : constant Choice := (if Preferred_Side = Right then Left else Right);
         Flat_Wall : constant Boolean := Wall_Profile (S, Wall_Right, Wall_Left);
         function Can_Turn (Direction : Choice) return Boolean is
           (Direction /= Avoid_Side
            and then ((Flat_Wall and then Rotation_Clear (S, Direction, Allow_Open => True))
                      or else Wall_Exit_Clear (S, Wall_Right, Wall_Left, Direction)));
      begin
         if Can_Turn (Preferred_Side) then
            return Preferred_Side;
         elsif Can_Turn (Other_Side) then
            return Other_Side;
         end if;
         return Blocked;
      end Wall_Choice;
      function Corridor_Rejection (Values : Distances) return Scan_Rejection is
      begin
         for D of Values loop
            if D = Open_Range then return Ray_Open;
            elsif not Valid (D) then return Ray_Unknown;
            elsif not Clear (D) then return Ray_Too_Close;
            end if;
         end loop;
         return Corridor_Too_Narrow;
      end Corridor_Rejection;
   begin
      if Stop_Requested then return R; end if;
      Recenter;
      if Stop_Requested then return R; end if;
      S := Read_Guard;
      if Stop_Requested then return R; end if;
      if Straight_Allowed and then Forward_Safe (S, Front_Limit) then R.Direction := Straight; return R; end if;
      if Pivot_Side_Too_Close (S.Left) or else Pivot_Side_Too_Close (S.Right) then
         return R;
      end if;
      -- Inspect the open side first when a fixed sensor sees a near wall.
      -- This also works before the first pivot and after a partial pivot.
      First := First_Side;
      if Wall_Pivot_Enabled and then Try_Wall and then Near_Wall_Clear (S, First, Wall_Limit) then
         Point (Angles (First) (2), Exit_Ray, Stamp);
         R.Points := R.Points + 1;
         if Stop_Requested then return R; end if;
         if Forward_Clear (Exit_Ray, Corner_Stop_Distance) then
            Recenter;
            S := Read_Guard;
            if Stop_Requested then return R; end if;
            Current := Now_Ms;
            if Stamp <= Current and then Current - Stamp <= Max_Pair_Age_Ms
              and then Near_Wall_Clear (S, First, Wall_Limit)
            then
               R.Direction := First;
               R.Wall_Pivot := True;
               R.Wall_Exit := True;
               R.Pivot_Guard := S;
               R.Oldest_Pair_Ms := Stamp;
               return R;
            end if;
         end if;
      end if;
      -- The motors are stopped: an unsafe guard must not prevent looking.
      -- The ordinary corridor search still uses the full turn guard.
      if Wall_Pivot_Enabled and then Try_Wall
        and then ((S.Front <= Wall_Probe_Range and then Wall_Guard_Clear (S))
                  or else (Try_Oblique_Wall and then Wall_Rotation_Clear (S)))
      then
         Point (Center - Corner_Angle, Wall_Right, Wall_First);
         R.Points := R.Points + 1;
         if Stop_Requested then return R; end if;
         -- An oblique obstacle may be visible on only one front diagonal.
         if Try_Oblique_Wall or else Wall_Profile (S, Wall_Right, S.Front) then
            Point (Center + Corner_Angle, Wall_Left, Wall_Second);
            R.Points := R.Points + 1;
            if Stop_Requested then return R; end if;
            if Wall_Choice /= Blocked then
               Recenter;
               S := Read_Guard;
               if Stop_Requested then return R; end if;
               Current := Now_Ms;
               First := Wall_Choice;
               if Wall_First <= Wall_Second and then Wall_Second <= Current
                 and then Current - Wall_First <= Max_Pair_Age_Ms
                 and then First in Left | Right
               then
                  R.Direction := First;
                  R.Wall_Pivot := True;
                  R.Wall_Exit := Wall_Exit_Clear (S, Wall_Right, Wall_Left, First);
                  R.Pivot_Guard := S;
                  R.Oldest_Pair_Ms := Wall_First;
                  return R;
               end if;
            end if;
         end if;
      end if;
      First := First_Side;
      Order := (First, (if First = Right then Left else Right));
      for Candidate of Order loop
         exit when Candidate = Avoid_Side;
         Pair := (others => 0);
         Oldest := Natural'Last;
         for I in Pair'Range loop
            exit when Stop_Requested;
            Point (Angles (Candidate) (I), Pair (I), Stamp);
            R.Points := R.Points + 1;
            Oldest := Natural'Min (Oldest, Stamp);
            -- A single rejected ray already invalidates this whole pair.
            exit when not Clear (Pair (I));
         end loop;
         if Stop_Requested then return R; end if;
         if Wide_Enough (Pair, Pair_Span_Degrees) then
            Recenter;
            S := Read_Guard;
            if Stop_Requested then return R; end if;
            -- If the obstacle has cleared while scanning, continuing forward
            -- avoids an unnecessary turn. This uses newly centered readings.
            if Straight_Allowed and then Forward_Safe (S, Front_Limit) then R.Direction := Straight; return R; end if;
            Current := Now_Ms;
            if Current >= Oldest then
               if Current - Oldest > Max_Pair_Age_Ms then
                  R.Expired_Pairs := R.Expired_Pairs + 1;
                  Report_Reject (Candidate, Evidence_Expired);
               elsif Acceptable (Pair, S, Candidate, Current - Oldest) then
                  R.Direction := Candidate;
                  R.Pivot_Guard := S;
                  R.Oldest_Pair_Ms := Oldest;
                  return R;
               else
                  Report_Reject (Candidate, Guard_Not_Clear);
               end if;
            else
               Report_Reject (Candidate, Invalid_Timestamp);
            end if;
         else
            Report_Reject (Candidate, Corridor_Rejection (Pair));
         end if;
      end loop;
      Recenter;
      return R;
   end Find;
end Adaptive_Quick_Scan;
