with Ada.Text_IO; use Ada.Text_IO;
with Adaptive_Policy; use Adaptive_Policy;
with Adaptive_Scan_Policy; use Adaptive_Scan_Policy;
with Adaptive_Quick_Scan;
procedure Scan_Tests is
   Checks, Clock_Ms, Guard_Calls, Point_Calls, Center_Calls : Natural := 0;
   Current_Angle, First_Angle : Natural := Center;
   S, Final_Guard : Snapshot := (30, 40, 50);
   Right_D, Left_D : Distance := 150;
   Expire, Stop, Unknown_First, Future_Stamp, Raise_In_Point : Boolean := False;
   Stop_After_Point : Natural := 0;
   Injected_Error : exception;
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if not Condition then raise Program_Error with Name; end if;
      Checks := Checks + 1;
   end Check;
   procedure Reset is
   begin
      Clock_Ms := 0; Guard_Calls := 0; Point_Calls := 0; Center_Calls := 0;
      Current_Angle := Center; First_Angle := 0;
      S := (30, 40, 50); Final_Guard := S;
      Right_D := 150; Left_D := 150;
      Expire := False; Stop := False; Unknown_First := False;
      Future_Stamp := False; Raise_In_Point := False; Stop_After_Point := 0;
   end Reset;
   procedure Recenter is
   begin
      Center_Calls := Center_Calls + 1;
      if Current_Angle /= Center then Clock_Ms := Clock_Ms + 500; end if;
      Current_Angle := Center;
   end Recenter;
   procedure Point (Angle : Natural; Value : out Distance;
                    Sample_Started_Ms : out Natural) is
   begin
      if Raise_In_Point then raise Injected_Error; end if;
      Point_Calls := Point_Calls + 1;
      if Point_Calls = 1 then First_Angle := Angle; end if;
      Clock_Ms := Clock_Ms + 500;
      Sample_Started_Ms := Clock_Ms + (if Future_Stamp then 10_000 else 0);
      Clock_Ms := Clock_Ms + 130;
      Current_Angle := Angle;
      Value := (if Angle < Center then Right_D else Left_D);
      if Unknown_First and Point_Calls = 1 then Value := 0; end if;
      if Point_Calls = Stop_After_Point then Stop := True; end if;
   end Point;
   function Guard return Snapshot is
   begin
      Check (Current_Angle = Center, "guard always measured facing forward");
      Guard_Calls := Guard_Calls + 1;
      Clock_Ms := Clock_Ms + 585;
      if Guard_Calls = 1 then return S; end if;
      if Expire then Clock_Ms := Clock_Ms + 2_500; end if;
      return Final_Guard;
   end Guard;
   function Now_Ms return Natural is (Clock_Ms);
   function Stop_Requested return Boolean is (Stop);
   package Search is new Adaptive_Quick_Scan (Recenter, Point, Guard, Now_Ms, Stop_Requested);
   R : Search.Scan_Result;
begin
   Check (not Acceptable ((123, 123), (30, 30, 30), 0), "too narrow");
   Check (Acceptable ((125, 125), (30, 30, 30), 2_000), "width and age boundary");
   Check (not Acceptable ((150, 150), (30, 30, 30), 2_001), "expired pair rejected");
   Check (not Acceptable ((150, 0), (30, 30, 30), 0), "unknown ray rejected");
   Check (not Acceptable ((150, 150), (30, 25, 30), 0), "side guard boundary");
   Check (not Acceptable ((150, 150, 150), (30, 30, 30), 0), "wrong ray count rejected");
   Reset; S := (100, 30, 30); R := Search.Find;
   Check (R.Direction = Straight and R.Points = 0, "clear front needs no scan");
   Reset; S := (20, 50, 50); R := Search.Find;
   Check (R.Direction = Blocked and R.Points = 0, "unsafe turning envelope skips scan");
   Reset; S.Left := 0; R := Search.Find;
   Check (R.Direction = Blocked and R.Points = 0, "unknown guard skips scan");
   Reset; R := Search.Find;
   Check (R.Direction = Right and R.Points = 2 and First_Angle = 72,
          "right preferred and first feasible pair terminates");
   Check (R.Oldest_Pair_Ms = 1_085, "carry original oldest ray time to drive gate");
   Reset; S := (30, 60, 40); Final_Guard := S; R := Search.Find;
   Check (R.Direction = Left and R.Points = 2 and First_Angle = 96, "left preferred");
   Reset; S := (30, 50, 50); Final_Guard := S; R := Search.Find (Left);
   Check (R.Direction = Left, "tie preserves prior choice");
   Reset; Final_Guard := (100, 30, 30); R := Search.Find;
   Check (R.Direction = Straight and R.Points = 2,
          "newly cleared front avoids an unnecessary turn");
   Reset; Right_D := 46; R := Search.Find;
   Check (R.Direction = Left and R.Points = 4, "reject narrow pair then use other side");
   Reset; Right_D := 46; Left_D := 46; R := Search.Find;
   Check (R.Direction = Blocked and R.Points = 4, "bounded unsuccessful search");
   Reset; Unknown_First := True; R := Search.Find;
   Check (R.Direction = Left and R.Points = 3, "unknown ray ends candidate early");
   Reset; Final_Guard.Left := 0; R := Search.Find;
   Check (R.Direction = Blocked and R.Points = 4, "changed guard vetoes both candidates");
   Reset; Expire := True; R := Search.Find;
   Check (R.Direction = Blocked and R.Expired_Pairs = 2, "all stale candidates vetoed");
   Reset; Future_Stamp := True; R := Search.Find;
   Check (R.Direction = Blocked, "future timestamps cannot grant clearance");
   Reset; Stop := True; R := Search.Find;
   Check (R.Direction = Blocked and Point_Calls = 0 and Guard_Calls = 0, "stop before scan");
   Reset; Stop_After_Point := 1; R := Search.Find;
   Check (R.Direction = Blocked and R.Points = 1 and Center_Calls = 1,
          "stop prevents subsequent servo commands");
   Reset; Raise_In_Point := True;
   begin
      R := Search.Find;
      Check (False, "hardware exception must propagate");
   exception when Injected_Error => null;
   end;
   Put_Line ("PASS" & Natural'Image (Checks) & " adaptive scan checks");
end Scan_Tests;
