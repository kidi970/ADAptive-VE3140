with Adaptive_Scan_Policy; use Adaptive_Scan_Policy;
package body Adaptive_Quick_Scan is
   function Find (Previous : Choice := Blocked) return Scan_Result is
      R : Scan_Result;
      S : Snapshot;
      First : Choice;
      type Direction_Pair is array (1 .. 2) of Choice;
      Order : Direction_Pair;
      Pair : Distances (1 .. 2);
      Stamp, Oldest, Current : Natural;
   begin
      if Stop_Requested then return R; end if;
      Recenter;
      if Stop_Requested then return R; end if;
      S := Read_Guard;
      if Stop_Requested then return R; end if;
      if Forward_Safe (S) then R.Direction := Straight; return R; end if;
      if not Turn_Safe (S) then return R; end if;
      First := Preferred (S, Previous);
      Order := (First, (if First = Right then Left else Right));
      for Candidate of Order loop
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
         if Wide_Enough (Pair, 12) then
            Recenter;
            S := Read_Guard;
            if Stop_Requested then return R; end if;
            -- If the obstacle has cleared while scanning, continuing forward
            -- avoids an unnecessary turn. This uses newly centered readings.
            if Forward_Safe (S) then R.Direction := Straight; return R; end if;
            Current := Now_Ms;
            if Current >= Oldest then
               if Current - Oldest > Max_Pair_Age_Ms then
                  R.Expired_Pairs := R.Expired_Pairs + 1;
               elsif Acceptable (Pair, S, Current - Oldest) then
                  R.Direction := Candidate;
                  R.Oldest_Pair_Ms := Oldest;
                  return R;
               end if;
            end if;
         end if;
      end loop;
      Recenter;
      return R;
   end Find;
end Adaptive_Quick_Scan;
