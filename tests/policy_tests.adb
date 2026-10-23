with Ada.Text_IO; use Ada.Text_IO;
with Adaptive_Policy; use Adaptive_Policy;
with Adaptive_FSM; use Adaptive_FSM;
procedure Policy_Tests is
   Checks : Natural := 0;
   procedure Check (Condition : Boolean; Name : String) is
   begin
      Checks := Checks + 1;
      if not Condition then raise Program_Error with Name; end if;
   end Check;
   S : Snapshot := (100, 30, 30);
   Five : Distances (1 .. 5) := (others => 130);
   Seven : Distances (1 .. 7) := (others => 100);
   Previous : Choice := Blocked;
   Count : Natural := 0;
   Accepted : Boolean;
   D : Distance;
begin
   Check (Filter (100, 102, 101) = 100, "agreeing readings");
   Check (Filter (0, 100, 100) = 0, "zero veto");
   Check (Filter (201, 100, 100) = 0, "out of range veto");
   Check (Filter (10, 100, 101) = 10, "near obstacle is retained");
   Check (Filter (20, 80, 150) = 0, "no agreement");
   Check (not Clear (45) and Clear (46), "front threshold inclusive stop");
   Check (not Clear (200, 200), "strict clearance");
   for I in Distance loop
      Check (not Clear (0, Natural (I)), "zero never clear");
      D := Filter (I, 100, 101);
      Check (D = 0 or else Valid (D), "filter range invariant");
      if not Valid (I) then Check (D = 0, "all invalid values veto"); end if;
      S := (I, 30, 30);
      if I <= 45 or I > 200 then
         Check (not Forward_Safe (S), "front safety sweep");
      end if;
      S := (100, I, 30);
      if I <= 15 or I > 200 then
         Check (not Forward_Safe (S), "left safety sweep");
      end if;
      S := (100, 30, I);
      if I <= 15 or I > 200 then
         Check (not Forward_Safe (S), "right safety sweep");
      end if;
   end loop;
   S := (30, 30, 30);
   Check (Turn_Safe (S), "turn envelope clear");
   S.Left := 25; Check (not Turn_Safe (S), "turn side boundary");
   S := (30, 30, 30);
   Check (not Wide_Enough ((46, 46), 12), "narrow corridor rejected");
   Check (Wide_Enough ((130, 130), 12), "wide corridor accepted");
   Check (not Wide_Enough ((100, 0, 100), 20), "unknown hole rejected");
   Five := (130, 130, 30, 20, 20);
   Check (Select_Five (Five, S) = Right, "5P right");
   Five := (20, 20, 30, 130, 130);
   Check (Select_Five (Five, S) = Left, "5P left");
   Five := (others => 100); S := (100, 30, 30);
   Check (Select_Five (Five, S) = Straight, "5P straight");
   S := (30, 30, 30); Seven := (100, 100, 100, 30, 20, 20, 20);
   Check (Select_Seven (Seven, S, 30) = Right, "7P right");
   Seven := (20, 20, 20, 30, 100, 100, 100);
   Check (Select_Seven (Seven, S, 30) = Left, "7P left");
   Check (Select_Seven (Seven, S, 60) = Blocked, "center mismatch");
   Seven := (0, 46, 21, 22, 23, 23, 162);
   Check (Select_Seven (Seven, S, 22) = Blocked, "reported blocked scene");
   for I in Seven'Range loop
      Seven := (100, 100, 100, 30, 20, 20, 20);
      if I <= 3 then
         Seven (I) := 0;
         Check (Select_Seven (Seven, S, 30) = Blocked, "corridor hole veto");
      end if;
   end loop;
   Confirm (Right, Previous, Count, Accepted);
   Check (not Accepted and Count = 1, "first candidate waits");
   Confirm (Left, Previous, Count, Accepted);
   Check (not Accepted and Count = 1, "direction change resets");
   Confirm (Blocked, Previous, Count, Accepted);
   Check (Count = 0 and not Accepted, "blocked resets");
   Confirm (Left, Previous, Count, Accepted);
   Confirm (Left, Previous, Count, Accepted);
   Check (Accepted and Count = 0, "second matching candidate consumed");
   for C in State loop
      Check (Next_State (C, Fatal) = Fault, "fatal latches");
   end loop;
   for E in Event loop
      Check (Next_State (Fault, E) = Fault, "fault cannot restart");
   end loop;
   Check (Next_State (Stopped, Recheck) = Verify, "startup verify");
   Check (Next_State (Verify, Clear_Path) = Cruise, "verified cruise");
   Check (Next_State (Cruise, Unsafe_Path) = Stopped, "motion unsafe stop");
   Check (Next_State (Verify, Unsafe_Path) = Scan, "blocked scan");
   Check (Next_State (Scan, Scan_Turn) = Turn, "scan turn");
   Check (Next_State (Turn, Turn_Done) = Verify, "turn must verify");
   Check (Next_State (Cruise, Scan_Turn) = Stopped, "unexpected event stops");
   Put_Line ("PASS" & Natural'Image (Checks) & " checks");
end Policy_Tests;
