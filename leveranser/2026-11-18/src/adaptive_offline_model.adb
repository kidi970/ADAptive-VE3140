with Ada.Numerics;
with Ada.Numerics.Elementary_Functions;

package body Adaptive_Offline_Model is
   use Adaptive_Policy;
   use Ada.Numerics.Elementary_Functions;

   function Finite (V : Float) return Boolean is
     (V >= -Float'Last and then V <= Float'Last);

   function Usable (S : Sample; Now_Ms, Max_Age_Ms : Natural) return Boolean is
     (S.Status = Measured and then Finite (S.Distance_M)
      and then S.Distance_M in 0.02 .. 2.0 and then S.Stamp_Ms <= Now_Ms
      and then Now_Ms - S.Stamp_Ms <= Max_Age_Ms);

   function Summarize (Values : Samples; Now_Ms, Max_Age_Ms : Natural)
                       return Statistics is
      R : Statistics;
      Delta_M, M2 : Float := 0.0;
   begin
      R.Total := Values'Length;
      for S of Values loop
         if Usable (S, Now_Ms, Max_Age_Ms) then
            R.Valid_Count := R.Valid_Count + 1;
            if R.Valid_Count = 1 then R.Minimum_M := S.Distance_M;
            else R.Minimum_M := Float'Min (R.Minimum_M, S.Distance_M); end if;
            --  Welford avoids cancellation in variance for almost equal data.
            Delta_M := S.Distance_M - R.Mean_M;
            R.Mean_M := R.Mean_M + Delta_M / Float (R.Valid_Count);
            M2 := M2 + Delta_M * (S.Distance_M - R.Mean_M);
         end if;
      end loop;
      if R.Total > 0 then
         R.Valid_Fraction := Float (R.Valid_Count) / Float (R.Total);
      end if;
      if R.Valid_Count > 0 then
         R.Population_SD_M := Sqrt (Float'Max (0.0, M2 / Float (R.Valid_Count)));
      end if;
      return R;
   end Summarize;

   function Stop_Clearance (P : Stop_Parameters) return Model_Value is
   begin
      if not (Finite (P.Speed_M_Per_S) and then Finite (P.Latency_S)
              and then Finite (P.Deceleration_M_Per_S2)
              and then Finite (P.Margin_M))
        or else P.Speed_M_Per_S not in 0.0 .. 20.0
        or else P.Latency_S not in 0.0 .. 60.0
        or else P.Deceleration_M_Per_S2 not in 0.001 .. 100.0
        or else P.Margin_M not in 0.0 .. 1_000.0
      then
         return (False, 0.0);
      end if;
      return (True, P.Speed_M_Per_S * P.Latency_S
              + P.Speed_M_Per_S ** 2 / (2.0 * P.Deceleration_M_Per_S2)
              + P.Margin_M);
   end Stop_Clearance;

   function Ray_Point (S : Sample; Servo_Command : Float;
                       Calibration : Angle_Calibration;
                       Now_Ms, Max_Age_Ms : Natural) return Point is
      C : Angle_Calibration renames Calibration;
      Angle : Float;
   begin
      if not C.Established or else not Usable (S, Now_Ms, Max_Age_Ms)
        or else not (Finite (Servo_Command) and then Finite (C.Center_Command)
          and then Finite (C.Degrees_Per_Command) and then Finite (C.Mount_Yaw_Degrees)
          and then Finite (C.Offset_X_M) and then Finite (C.Offset_Y_M))
        or else Servo_Command not in 0.0 .. 180.0
        or else C.Center_Command not in 0.0 .. 180.0
        or else abs C.Degrees_Per_Command not in 0.01 .. 2.0
        or else abs C.Mount_Yaw_Degrees > 360.0
        or else abs C.Offset_X_M > 10.0 or else abs C.Offset_Y_M > 10.0
      then
         return (False, 0.0, 0.0);
      end if;
      Angle := ((Servo_Command - C.Center_Command) * C.Degrees_Per_Command
                + C.Mount_Yaw_Degrees) * Ada.Numerics.Pi / 180.0;
      return (True, C.Offset_X_M + S.Distance_M * Cos (Angle),
              C.Offset_Y_M + S.Distance_M * Sin (Angle));
   end Ray_Point;

   function Sampled_Opening (Nearest_Range_M, Angular_Span_Degrees : Float)
                             return Model_Value is
   begin
      if not (Finite (Nearest_Range_M) and then Finite (Angular_Span_Degrees))
        or else Nearest_Range_M not in 0.02 .. 2.0
        or else Angular_Span_Degrees <= 0.0 or else Angular_Span_Degrees > 180.0
      then
         return (False, 0.0);
      end if;
      return (True, 2.0 * Nearest_Range_M
              * Sin (Angular_Span_Degrees * Ada.Numerics.Pi / 360.0));
   end Sampled_Opening;

   function Plan (Scan : Samples; Guard : Guard_Samples;
                  Previous_Center : Sample; Previous : Choice;
                  Stop : Stop_Parameters; Now_Ms, Max_Age_Ms, Generation : Natural;
                  Hysteresis_M : Float := 0.05) return Decision is
      R : Decision := (Blocked, Generation, Now_Ms, Now_Ms, False);
      Required : constant Model_Value := Stop_Clearance (Stop);
      --  Bounded storage regardless of an erroneous caller's array length.
      Values : Distances (1 .. 7) := (others => 0);
      G : Snapshot;
      Right_OK, Left_OK : Boolean := False;
      Right_Score, Left_Score : Float := 0.0;
      function CM (S : Sample) return Distance is
        (Distance (Float'Floor (S.Distance_M * 100.0)));
      function Greater_Than_Stop (A : Distances) return Boolean is
      begin
         for D of A loop
            if Float (D) / 100.0 <= Required.Value then return False; end if;
         end loop;
         return True;
      end Greater_Than_Stop;
      function Nearest (A : Distances) return Float is
         N : Distance := Distance'Last;
      begin
         for D of A loop N := Distance'Min (N, D); end loop;
         return Float (N) / 100.0;
      end Nearest;
   begin
      if Generation = 0 or else Scan'First /= 1
        or else Scan'Length not in 1 | 5 | 7 or else not Required.Valid
        or else not Finite (Hysteresis_M) or else Hysteresis_M not in 0.0 .. 1.0
        or else not Usable (Guard.Front, Now_Ms, Max_Age_Ms)
        or else not Usable (Guard.Left, Now_Ms, Max_Age_Ms)
        or else not Usable (Guard.Right, Now_Ms, Max_Age_Ms)
      then return R; end if;
      R.Oldest_Ms := Natural'Min (Guard.Front.Stamp_Ms,
        Natural'Min (Guard.Left.Stamp_Ms, Guard.Right.Stamp_Ms));
      for I in Scan'Range loop
         if not Usable (Scan (I), Now_Ms, Max_Age_Ms) then return R; end if;
         Values (I) := CM (Scan (I));
         R.Oldest_Ms := Natural'Min (R.Oldest_Ms, Scan (I).Stamp_Ms);
      end loop;
      G := (CM (Guard.Front), CM (Guard.Left), CM (Guard.Right));
      --  An independent current front reading must agree with the scan center.
      if abs (Scan ((Scan'Length + 1) / 2).Distance_M - Guard.Front.Distance_M) > 0.15
      then return R; end if;
      if Scan'Length = 1 then
         if Forward_Safe (G) and then Clear (Values (1))
           and then Greater_Than_Stop ((G.Front, Values (1)))
         then R.Direction := Straight; end if;
         return R;
      elsif Scan'Length = 5 then
         if Forward_Safe (G) and then Wide_Enough (Values (2 .. 4), 24)
           and then Greater_Than_Stop ((G.Front, Values (2), Values (3), Values (4)))
         then R.Direction := Straight; return R; end if;
         Right_OK := Wide_Enough (Values (1 .. 2), 12)
           and then Greater_Than_Stop (Values (1 .. 2));
         Left_OK := Wide_Enough (Values (4 .. 5), 12)
           and then Greater_Than_Stop (Values (4 .. 5));
         Right_Score := Nearest (Values (1 .. 2));
         Left_Score := Nearest (Values (4 .. 5));
      else
         if not Usable (Previous_Center, Now_Ms, Max_Age_Ms)
           or else abs (Previous_Center.Distance_M - Scan (4).Distance_M) > 0.15
         then return R; end if;
         R.Oldest_Ms := Natural'Min (R.Oldest_Ms, Previous_Center.Stamp_Ms);
         Right_OK := Wide_Enough (Values (1 .. 3), 20)
           and then Greater_Than_Stop (Values (1 .. 3));
         Left_OK := Wide_Enough (Values (5 .. 7), 20)
           and then Greater_Than_Stop (Values (5 .. 7));
         Right_Score := Nearest (Values (1 .. 3));
         Left_Score := Nearest (Values (5 .. 7));
      end if;
      if not Turn_Safe (G)
        or else not Greater_Than_Stop ((G.Front, G.Left, G.Right))
      then return R; end if;
      if Right_OK and Left_OK then
         if Previous = Right and Left_Score - Right_Score <= Hysteresis_M
         then R.Direction := Right;
         elsif Previous = Left and Right_Score - Left_Score <= Hysteresis_M
         then R.Direction := Left;
         elsif Right_Score >= Left_Score then R.Direction := Right;
         else R.Direction := Left; end if;
      elsif Right_OK then R.Direction := Right;
      elsif Left_OK then R.Direction := Left;
      end if;
      return R;
   end Plan;

   procedure Consume (D : in out Decision; State : in out Consumption_State;
                      Now_Ms, Max_Age_Ms,
                      Observation_Generation : Natural; Allowed : out Boolean) is
   begin
      Allowed := not D.Consumed and then D.Direction /= Blocked
        and then D.Generation /= 0 and then D.Generation = Observation_Generation
        and then D.Generation > State.Last_Generation
        and then (not State.Has_Accepted
          or else D.Oldest_Ms > State.Last_Accepted_Issued_Ms)
        and then D.Oldest_Ms <= D.Issued_Ms and then D.Issued_Ms <= Now_Ms
        and then Now_Ms - D.Oldest_Ms <= Max_Age_Ms;
      D.Consumed := True;
      State.Last_Generation := Natural'Max (State.Last_Generation, D.Generation);
      if Allowed then
         State.Last_Accepted_Issued_Ms := D.Issued_Ms;
         State.Has_Accepted := True;
      end if;
   end Consume;
end Adaptive_Offline_Model;
