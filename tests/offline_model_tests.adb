with Ada.Text_IO; use Ada.Text_IO;
with Ada.Unchecked_Conversion;
with Interfaces;
with Adaptive_Policy; use Adaptive_Policy;
with Adaptive_Offline_Model; use Adaptive_Offline_Model;

procedure Offline_Model_Tests is
   Checks : Natural := 0;
   function From_Bits is new Ada.Unchecked_Conversion (Interfaces.Unsigned_32, Float);
   NaN : constant Float := From_Bits (16#7FC0_0000#);
   Infinity : constant Float := From_Bits (16#7F80_0000#);
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if not Condition then raise Program_Error with Name; end if;
      Checks := Checks + 1;
   end Check;
   function Near (A, B : Float) return Boolean is (abs (A - B) < 0.000_01);
   function M (D : Float; Stamp : Natural := 1_000) return Sample is
     ((Measured, D, Stamp));
   Base_Stop : constant Stop_Parameters := (0.0, 0.2, 0.5, 0.05);
   P : Stop_Parameters := Base_Stop;
   V, Last : Model_Value;
   Stats : Statistics;
   C : Angle_Calibration;
   Q : Point;
   S5 : Samples (1 .. 5) := (M (1.5), M (1.5), M (0.3), M (1.5), M (1.5));
   S7 : Samples (1 .. 7) := (M (1.5), M (1.5), M (1.5), M (0.3),
                            M (1.5), M (1.5), M (1.5));
   G : Guard_Samples := (M (0.3), M (0.5), M (0.5));
   D, Copy : Decision;
   State : Consumption_State;
   Allowed : Boolean;
   function Five (Previous : Choice := Blocked; Stop : Stop_Parameters := Base_Stop)
                  return Decision is
     (Plan (S5, G, M (0.3), Previous, Stop, 1_000, 2_000, 1));
begin
   Check (Usable (M (0.02), 1_000, 0), "lower range boundary");
   Check (Usable (M (2.0), 3_000, 2_000), "upper range and age boundary");
   Check (not Usable (M (2.0), 3_001, 2_000), "stale sample rejected");
   Check (not Usable (M (1.0), 999, 2_000), "future sample rejected without subtraction underflow");
   Check (Usable (M (1.0, Natural'Last), Natural'Last, 0), "large timestamps do not overflow");
   for Bad of Samples'(M (0.0), M (-1.0), M (0.019), M (2.01), M (NaN), M (Infinity)) loop
      Check (not Usable (Bad, 1_000, 2_000), "nonfinite or outside range is unknown");
   end loop;
   for Status in Sample_Status loop
      Check (Usable ((Status, 1.0, 1_000), 1_000, 2_000) = (Status = Measured),
             "timeout and missing flags veto even a long numeric value");
   end loop;
   Stats := Summarize ((M (0.5), M (1.0), M (1.5), M (0.0), M (1.0, 5_000)),
                       1_000, 2_000);
   Check (Stats.Total = 5 and Stats.Valid_Count = 3 and Near (Stats.Valid_Fraction, 0.6),
          "validity denominator includes invalid data");
   Check (Near (Stats.Minimum_M, 0.5) and Near (Stats.Mean_M, 1.0)
          and Near (Stats.Population_SD_M, 0.408_248_3), "descriptive population statistics");
   Stats := Summarize ((1 => M (1.25)), 1_000, 2_000);
   Check (Stats.Valid_Count = 1 and Near (Stats.Mean_M, 1.25)
          and Stats.Population_SD_M = 0.0, "single valid sample has zero population deviation");
   Stats := Summarize ((1 => M (0.0)), 1_000, 2_000);
   Check (Stats.Valid_Count = 0 and Stats.Mean_M = 0.0 and Stats.Valid_Fraction = 0.0,
          "empty valid set has explicit zero count");
   Stats := Summarize ((1 .. 0 => M (1.0)), 1_000, 2_000);
   Check (Stats.Total = 0 and Stats.Valid_Fraction = 0.0, "empty array avoids division by zero");
   Stats := Summarize ((M (1.0), M (1.000_001), M (1.000_002)), 1_000, 2_000);
   Check (Stats.Population_SD_M >= 0.0 and Stats.Population_SD_M < 0.000_01,
          "near equal data do not give negative variance");

   V := Stop_Clearance ((0.5, 0.2, 1.0, 0.05));
   Check (V.Valid and Near (V.Value, 0.275), "SI reaction plus braking plus margin");
   V := Stop_Clearance (Base_Stop);
   Check (V.Valid and Near (V.Value, 0.05), "stationary bound retains margin");
   Last := V;
   for I in 1 .. 40 loop
      P := (Float (I) / 20.0, 0.2, 0.5, 0.05);
      V := Stop_Clearance (P);
      Check (V.Valid and V.Value > Last.Value, "stop bound strictly increases with speed");
      Last := V;
   end loop;
   V := Stop_Clearance ((20.0, 60.0, 0.001, 1_000.0));
   Check (V.Valid and V.Value > 200_000.0, "bounded parameter domain avoids overflow");
   for Index in 1 .. 4 loop
      for Bad_Index in 1 .. 3 loop
         P := (0.5, 0.2, 0.5, 0.05);
         declare
            Bad : constant Float := (case Bad_Index is when 1 => NaN,
                                      when 2 => Infinity, when others => -1.0);
         begin
            case Index is
               when 1 => P.Speed_M_Per_S := Bad;
               when 2 => P.Latency_S := Bad;
               when 3 => P.Deceleration_M_Per_S2 := Bad;
               when others => P.Margin_M := Bad;
            end case;
         end;
         Check (not Stop_Clearance (P).Valid, "invalid stop parameter never gives clearance");
      end loop;
   end loop;
   Check (not Stop_Clearance ((0.5, 0.2, 0.0, 0.05)).Valid, "zero braking denominator rejected");
   Check (not Stop_Clearance ((0.5, 0.2, 0.000_1, 0.05)).Valid, "outside braking domain rejected");
   Check (not Stop_Clearance ((20.1, 0.2, 0.5, 0.05)).Valid, "speed beyond model domain rejected");
   Check (Stop_Clearance ((0.5, 0.3, 0.5, 0.05)).Value
          > Stop_Clearance ((0.5, 0.2, 0.5, 0.05)).Value, "latency tightens bound");
   Check (Stop_Clearance ((0.5, 0.2, 0.25, 0.05)).Value
          > Stop_Clearance ((0.5, 0.2, 0.5, 0.05)).Value, "weaker braking tightens bound");

   Q := Ray_Point (M (1.0), 84.0, C, 1_000, 2_000);
   Check (not Q.Valid, "uncalibrated command has no assumed physical direction");
   C.Established := True; C.Offset_X_M := 0.1; C.Offset_Y_M := 0.2;
   Q := Ray_Point (M (1.0), 84.0, C, 1_000, 2_000);
   Check (Q.Valid and Near (Q.X_M, 1.1) and Near (Q.Y_M, 0.2), "front ray includes sensor offset");
   Q := Ray_Point (M (1.0), 134.0, C, 1_000, 2_000);
   Check (Q.Valid and Near (Q.X_M, 0.742_787_6) and Near (Q.Y_M, 0.966_044_4),
          "134 command means fifty degrees under synthetic unit calibration, not ninety");
   C.Degrees_Per_Command := -1.0;
   Q := Ray_Point (M (1.0), 134.0, C, 1_000, 2_000);
   Check (Q.Valid and Near (Q.Y_M, -0.566_044_4), "calibration slope controls orientation");
   C.Mount_Yaw_Degrees := 90.0;
   Q := Ray_Point (M (1.0), 84.0, C, 1_000, 2_000);
   Check (Q.Valid and Near (Q.X_M, 0.1) and Near (Q.Y_M, 1.2), "mount yaw is explicit");
   Check (not Ray_Point (M (1.0), NaN, C, 1_000, 2_000).Valid, "NaN command rejected");
   Check (not Ray_Point (M (1.0), 181.0, C, 1_000, 2_000).Valid, "command range rejected");
   Check (not Ray_Point (M (1.0, 0), 84.0, C, 3_000, 2_000).Valid, "stale ray has no coordinate");
   C.Offset_X_M := Infinity;
   Check (not Ray_Point (M (1.0), 84.0, C, 1_000, 2_000).Valid, "nonfinite offset rejected");
   C := (True, 84.0, 0.0, 0.0, 0.0, 0.0);
   Check (not Ray_Point (M (1.0), 84.0, C, 1_000, 2_000).Valid, "zero calibration slope rejected");
   V := Sampled_Opening (1.25, 12.0);
   Check (V.Valid and Near (V.Value, 0.261_321_2), "sampled chord uses metres and physical degrees");
   Check (Sampled_Opening (1.23, 12.0).Value < 0.26, "narrow sampled opening rejected by width threshold");
   Check (not Sampled_Opening (1.25, 0.0).Valid, "zero angular span rejected");
   Check (not Sampled_Opening (1.25, 181.0).Valid, "unsupported angular span rejected");
   Check (not Sampled_Opening (NaN, 12.0).Valid, "nonfinite geometric range rejected");
   Check (not Sampled_Opening (1.25, Infinity).Valid, "nonfinite angular span rejected");

   D := Five;
   Check (D.Direction = Right, "two eligible corridors choose deterministically");
   Check (Five (Left).Direction = Left, "hysteresis retains eligible previous side");
   S5 (4) := M (1.53); S5 (5) := M (1.53);
   Check (Five (Right).Direction = Right, "small benefit cannot chatter between sides");
   S5 (4) := M (1.6); S5 (5) := M (1.6);
   Check (Five (Right).Direction = Left, "larger verified clearance defeats hysteresis");
   S5 (1) := M (1.0);
   Check (Five (Right).Direction = Left, "hysteresis cannot resurrect ineligible side");
   S5 (5) := M (0.3);
   Check (Five.Direction = Blocked, "isolated long ray is not a corridor");
   S5 := (M (0.3), M (0.3), M (0.3), M (0.3), M (0.3));
   Check (Five.Direction = Blocked, "no supported corridor stops");
   S5 := (M (1.5), M (1.5), M (1.0), M (1.5), M (1.5));
   G.Front := M (1.0);
   Check (Five.Direction = Straight, "free front takes precedence over a turn");
   D := Plan ((1 => M (1.0)), G, M (0.0), Blocked, Base_Stop, 1_000, 2_000, 1);
   Check (D.Direction = Straight, "1P confirms only straight motion");
   G.Front := M (0.3);
   D := Plan ((1 => M (0.3)), G, M (0.0), Right, Base_Stop, 1_000, 2_000, 1);
   Check (D.Direction = Blocked, "1P cannot infer a turn from prior direction");
   S5 := (M (1.5), M (1.5), M (0.3), M (1.5), M (1.5));
   Check (Five (Blocked, (1.0, 0.2, 0.5, 0.05)).Direction = Blocked,
          "SI stop bound tightens static guard despite wide scan");
   Check (Five (Blocked, (0.5, 0.2, 0.0, 0.05)).Direction = Blocked,
          "invalid physical model never grants motion");
   G.Left := M (0.25);
   Check (Five.Direction = Blocked, "absolute turn guard cannot be softened");
   G.Left := M (0.5);
   for I in S5'Range loop
      declare Saved : constant Sample := S5 (I); begin
         S5 (I).Status := Timed_Out;
         Check (Five.Direction = Blocked, "every supplied scan ray must be valid");
         S5 (I) := Saved;
      end;
   end loop;
   S5 (1).Stamp_Ms := 1_001;
   Check (Five.Direction = Blocked, "future scan stamp cannot grant motion");
   S5 (1).Stamp_Ms := 0;
   D := Plan (S5, G, M (0.3), Blocked, Base_Stop, 3_001, 2_000, 1);
   Check (D.Direction = Blocked, "stale scan stamp vetoes decision");
   S5 (1).Stamp_Ms := 1_000;
   G.Right.Status := Missing;
   Check (Five.Direction = Blocked, "missing fixed guard cannot be replaced by scan");
   G.Right.Status := Measured;
   D := Plan (S7, G, M (0.3), Blocked, Base_Stop, 1_000, 2_000, 1);
   Check (D.Direction = Right, "7P independently confirmed center and two safe alternatives");
   D := Plan (S7, G, M (0.5), Blocked, Base_Stop, 1_000, 2_000, 1);
   Check (D.Direction = Blocked, "7P changed center fails independent confirmation");
   D := Plan (S7, G, M (0.459), Blocked, Base_Stop, 1_000, 2_000, 1);
   Check (D.Direction = Blocked, "7P SI center mismatch cannot shrink under centimetre flooring");
   G.Front := M (0.459);
   Check (Five.Direction = Blocked, "5P SI guard mismatch cannot shrink under centimetre flooring");
   G.Front := M (0.3);
   D := Plan (S7, G, (Missing, 0.3, 1_000), Left, Base_Stop, 1_000, 2_000, 1);
   Check (D.Direction = Blocked, "7P missing previous center fails closed");
   D := Plan ((1 .. 8 => M (1.5)), G, M (0.3), Left, Base_Stop, 1_000, 2_000, 1);
   Check (D.Direction = Blocked, "unsupported count rejected before bounded array indexing");
   D := Plan ((2 .. 6 => M (1.5)), G, M (0.3), Left, Base_Stop, 1_000, 2_000, 1);
   Check (D.Direction = Blocked, "unexpected array bounds rejected");
   D := Plan (S5, G, M (0.3), Left, Base_Stop, 1_000, 2_000, 1, NaN);
   Check (D.Direction = Blocked, "nonfinite hysteresis rejected");
   D := Plan (S5, G, M (0.3), Left, Base_Stop, 1_000, 2_000, 0);
   Check (D.Direction = Blocked, "generation zero is never new evidence");
   D := Five; Copy := D;
   Consume (D, State, 3_000, 2_000, 1, Allowed);
   Check (Allowed, "decision consumed at exact oldest sample age budget");
   Consume (D, State, 3_000, 2_000, 1, Allowed);
   Check (not Allowed, "same record cannot authorize twice");
   Consume (Copy, State, 3_000, 2_000, 1, Allowed);
   Check (not Allowed, "copy cannot turn old evidence into a new decision");
   D := Five; D.Generation := 2;
   Consume (D, State, 3_001, 2_000, 2, Allowed);
   Check (not Allowed, "decision freshness checked again at use");
   D := Five; D.Generation := 3;
   Consume (D, State, 999, 2_000, 3, Allowed);
   Check (not Allowed, "clock reversal vetoes decision");
   D := Five; D.Generation := 4;
   Consume (D, State, 1_000, 2_000, 5, Allowed);
   Check (not Allowed, "different current observation generation vetoes decision");
   D := Five; D.Generation := 6;
   Consume (D, State, 1_000, 2_000, 6, Allowed);
   Check (not Allowed, "larger generation cannot turn same measurements into new confirmation");
   --  All acquisition timestamps advance, not merely the decision identifier.
   for I in S5'Range loop S5 (I).Stamp_Ms := 1_001; end loop;
   G := (M (0.3, 1_001), M (0.5, 1_001), M (0.5, 1_001));
   D := Plan (S5, G, M (0.3, 1_001), Blocked, Base_Stop, 1_001, 2_000, 7);
   Copy := D;
   Consume (D, State, 1_001, 2_000, 7, Allowed);
   Check (Allowed, "new generation with every observation newly acquired can authorize once");
   Copy.Generation := 8;
   Consume (Copy, State, 1_001, 2_000, 8, Allowed);
   Check (not Allowed, "copied direction with newer ID still needs new observations");
   for I in S5'Range loop S5 (I).Stamp_Ms := 1_002; end loop;
   G.Front := M (0.3, 1_002); G.Left := M (0.5, 1_002);
   --  Keeping even one guard at the last issue time vetoes the entire token.
   D := Plan (S5, G, M (0.3, 1_002), Blocked, Base_Stop, 1_002, 2_000, 9);
   Consume (D, State, 1_002, 2_000, 9, Allowed);
   Check (not Allowed, "partly renewed guard set cannot reuse old confirmation");
   G.Right := M (0.5, 1_002);
   D := Plan (S5, G, M (0.3, 1_002), Blocked, Base_Stop, 1_002, 2_000, 10);
   Consume (D, State, 1_002, 2_000, 10, Allowed);
   Check (Allowed, "renewed complete observation set passes watermark");
   for I in S5'Range loop S5 (I).Stamp_Ms := 1_003; end loop;
   G := (M (0.3, 1_003), M (0.5, 1_003), M (0.5, 1_003));
   D := Plan (S5, G, M (0.3, 1_003), Blocked, Base_Stop, 1_003, 2_000, 10);
   Consume (D, State, 1_003, 2_000, 10, Allowed);
   Check (not Allowed, "new observations still cannot reuse consumed generation");
   D := Plan (S5, G, M (0.3, 1_003), Blocked, Base_Stop, 1_003, 2_000, 11);
   Consume (D, State, 1_003, 2_000, 11, Allowed);
   Check (Allowed, "new observations and new generation satisfy both gates");
   Put_Line ("PASS" & Natural'Image (Checks) & " offline mathematical model checks");
end Offline_Model_Tests;
