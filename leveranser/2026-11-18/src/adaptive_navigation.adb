with Adaptive_Sensors; use Adaptive_Sensors;
with Adaptive_Motion;
with Adaptive_Display;
with Ada.Real_Time; use Ada.Real_Time;
with Adaptive_Quick_Scan;
with Adaptive_Scan_Policy;
with Adaptive_Safety;
with Adaptive_Proximity;
with Adaptive_Log; use Adaptive_Log;
package body Adaptive_Navigation is
   use Adaptive_Scan_Policy;
   Previous : Choice := Blocked;
   Wall_Pivot_Selected, Wall_Exit_Selected : Boolean := False;
   Wall_Direction : Choice := Blocked;
   Pivot_Direction : Choice := Blocked;
   Pivot_Guard : Snapshot;
   Need_Measured_Exit : Boolean := False;
   subtype Forward_View is Choice range Straight .. Left;
   Near_Echo : array (Forward_View) of Boolean := (others => False);
   subtype Side_Choice is Choice range Right .. Left;
   Seen_Wall : array (Side_Choice) of Boolean := (others => False);
   type Side_Reading is record
      Last, Approach_Reference : Distance := 0;
   end record;
   Side_Readings : array (Side_Choice) of Side_Reading := (others => <>);
   Closing_Side : Choice := Blocked;
   Pass_Side : Choice := Blocked;
   Pass_Reference : Distance := 0;
   Short_Pass : Boolean := False;
   Pass_Side_Limit : constant := 8;
   Pass_Closing_Margin : constant := 2;
   Side_Approach_Drop : constant := 3;
   Approach_Reference_Min : constant := Side_Distance + Side_Approach_Drop;
   Leaving_Wall : Boolean := False;
   Exit_Distance : constant := Wall_Release_Distance;
   subtype Wall_Step_Count is Natural range 0 .. 4;
   Wall_Steps : Wall_Step_Count := 0;
   subtype Cruise_Index is Natural range 0 .. 3;
   Cruise_Views : constant array (Cruise_Index) of Choice :=
     [Right, Straight, Left, Straight];
   Next_View : Cruise_Index := Cruise_Index'First;

   function View_Angle (View : Choice) return Natural is
     (case View is
         when Right => Center - Adaptive_Scan_Policy.Corner_Angle,
         when Left => Center + Adaptive_Scan_Policy.Corner_Angle,
         when Straight | Blocked => Center);
   Turn_Deadline : Time := Time_First;
   function Turn_Evidence_Fresh return Boolean is
     (Clock <= Turn_Deadline and then not Adaptive_Safety.Stop_Requested);

   procedure Remember_Wall (Side : Side_Choice; D : Distance) is
   begin
      if Valid (D) and then D <= Wall_Release_Side_Distance then
         Seen_Wall (Side) := True;
      end if;
   end Remember_Wall;

   function Pass_Gap_Clear (D, Reference : Distance) return Boolean is
     (Clear (D, Pass_Side_Limit) and then D + Pass_Closing_Margin >= Reference);

   function Forward_Side_Clear (Side : Side_Choice; D : Distance) return Boolean is
     (if Closing_Side = Side then Clear (D, Side_Approach_Distance)
      elsif Pass_Side = Side then Pass_Gap_Clear (D, Pass_Reference)
      elsif (Need_Measured_Exit or else Leaving_Wall) and then Seen_Wall (Side)
      then Clear (D, Wall_Release_Side_Distance) else Forward_Clear (D, Side_Distance));

   procedure Show_Blocker (Name : String; D : Distance) is
      Status : constant String :=
        Name & (if D = Open_Range then " OPEN"
                elsif not Valid (D) then " INVALID" else Distance'Image (D) & "CM");
   begin
      Adaptive_Display.Show_Front (Status);
      Put_Line ("WAIT " & Status);
   end Show_Blocker;

   procedure Note_Turn_Started (Direction : Choice) is
   begin
      Previous := Direction;
      Wall_Direction := Direction;
      Need_Measured_Exit := True;
      Pass_Side := Blocked;
      Short_Pass := False;
      Side_Readings := (others => <>);
      if Direction /= Closing_Side then Closing_Side := Blocked; end if;
      Remember_Wall (Left, Pivot_Guard.Left);
      Remember_Wall (Right, Pivot_Guard.Right);
      if Wall_Pivot_Selected then
         Wall_Steps := Wall_Steps + 1;
      end if;
   end Note_Turn_Started;

   function Check_Forward_Corners (Frame : Snapshot) return Boolean is
      Right_Distance, Left_Distance, Center_Distance : Distance;
      Candidate : Choice := Blocked;
      Left_Clear, Right_Clear : Boolean;
      function Near_Corner (D : Distance) return Boolean is
        (Valid (D) and then D <= Corner_Stop_Distance);
      function Check (Angle : Natural; Name : String) return Distance is
         D : Distance;
      begin
         if Adaptive_Safety.Stop_Requested then return 0; end if;
         Adaptive_Motion.Aim (Angle);
         delay 0.5;
         D := Filtered (Front);
         Put_Line ("CORNER " & Name
                   & (if D = Open_Range then " OPEN"
                      elsif D = 0 then " UNKNOWN"
                      else " CM" & Distance'Image (D)));
         return D;
      end Check;
      function Exit_Clear (View : Forward_View; D : Distance) return Boolean is
        (Clear (D, Exit_Distance)
         or else (Candidate in Left | Right and then D = Open_Range and then not Near_Echo (View)));
   begin
      Pass_Side := Blocked;
      Short_Pass := False;
      if Closing_Side in Left | Right then
         declare
            Gap : constant Distance := (if Closing_Side = Left then Frame.Left else Frame.Right);
         begin
            if not Clear (Gap, Side_Approach_Distance) then
               Show_Blocker ((if Closing_Side = Left then "L GAP" else "R GAP"), Gap);
               return False;
            end if;
         end;
      end if;
      if Need_Measured_Exit then
         Remember_Wall (Left, Frame.Left);
         Remember_Wall (Right, Frame.Right);
      end if;
      Left_Clear := Forward_Side_Clear (Left, Frame.Left);
      Right_Clear := Forward_Side_Clear (Right, Frame.Right);
      if Right_Clear and then not Left_Clear and then Clear (Frame.Left, Pass_Side_Limit) then
         Candidate := Left;
      elsif Left_Clear and then not Right_Clear and then Clear (Frame.Right, Pass_Side_Limit) then
         Candidate := Right;
      elsif not (Left_Clear and then Right_Clear) then
         if not Right_Clear then Show_Blocker ("R", Frame.Right);
         else Show_Blocker ("L", Frame.Left); end if;
         return False;
      end if;
      Need_Measured_Exit := Need_Measured_Exit or else Candidate /= Blocked;
      Adaptive_Display.Show_Status ("STATUS: SCAN");
      Adaptive_Proximity.State.Observe (0);
      Next_View := Cruise_Index'First;
      Wall_Pivot_Selected := False;
      Right_Distance := Check (View_Angle (Right), "RIGHT");
      Left_Distance := Check (View_Angle (Left), "LEFT");
      if Adaptive_Safety.Stop_Requested then return False; end if;
      Adaptive_Motion.Aim (Center);
      delay 0.5;
      if Adaptive_Safety.Stop_Requested then return False; end if;
      if Near_Corner (Right_Distance) or else Near_Corner (Left_Distance)
        or else (Near_Echo (Right) and then not Valid (Right_Distance))
        or else (Near_Echo (Left) and then not Valid (Left_Distance))
      then
         Need_Measured_Exit := True;
      end if;
      if Need_Measured_Exit then
         Center_Distance := Filtered (Front);
         if Adaptive_Safety.Stop_Requested then return False; end if;
         -- A completed open pulse can only permit a short straight step
         -- beside a currently measured object. Preserve any seen close echo.
         if Valid (Center_Distance) then Near_Echo (Straight) := Center_Distance <= Exit_Distance; end if;
         if Valid (Right_Distance) then Near_Echo (Right) := Right_Distance <= Exit_Distance; end if;
         if Valid (Left_Distance) then Near_Echo (Left) := Left_Distance <= Exit_Distance; end if;
         if not Exit_Clear (Straight, Center_Distance) then
            Show_Blocker ("FRONT", Center_Distance);
            return False;
         elsif not Exit_Clear (Right, Right_Distance) then
            Show_Blocker ("CR", Right_Distance);
            return False;
         elsif not Exit_Clear (Left, Left_Distance) then
            Show_Blocker ("CL", Left_Distance);
            return False;
         end if;
         if Candidate in Left | Right then
            declare
               Initial_Gap : constant Distance := (if Candidate = Left then Frame.Left else Frame.Right);
               Fresh_Gap : constant Distance := Raw (if Candidate = Left then Left else Right);
            begin
               if Adaptive_Safety.Stop_Requested then return False; end if;
               if not Pass_Gap_Clear (Fresh_Gap, Initial_Gap) then
                  Show_Blocker ((if Candidate = Left then "L" else "R"), Fresh_Gap);
                  return False;
               end if;
               Pass_Side := Candidate;
               Pass_Reference := Distance'Max (Initial_Gap, Fresh_Gap);
               Short_Pass := Center_Distance = Open_Range or else Right_Distance = Open_Range
                 or else Left_Distance = Open_Range;
               Put_Line ("PASS " & (if Short_Pass then "STEP " else "SIDE ") & Choice'Image (Candidate));
            end;
         end if;
         Adaptive_Display.Show_Front ("");
         return True;
      end if;
      Near_Echo (Right) := Valid (Right_Distance) and then Right_Distance <= Exit_Distance;
      Near_Echo (Left) := Valid (Left_Distance) and then Left_Distance <= Exit_Distance;
      if not Forward_Clear (Right_Distance, Corner_Stop_Distance) then
         Show_Blocker ("CR", Right_Distance);
         return False;
      elsif not Forward_Clear (Left_Distance, Corner_Stop_Distance) then
         Show_Blocker ("CL", Left_Distance);
         return False;
      end if;
      Adaptive_Display.Show_Front ("");
      return True;
   end Check_Forward_Corners;

   function Scan_Path (Allow_Straight : Boolean := True) return Choice is
      Started : constant Time := Clock;
      Current_Angle : Natural := Center;
      Center_Ready_At : Time := Time_First;
      Scanning_Shown : Boolean := False;
      function Now_Ms return Natural is
        (Natural (To_Duration (Clock - Started) * 1_000.0));
      function Stop_Requested return Boolean is
        (Adaptive_Safety.Stop_Requested);
      procedure Recenter is
      begin
         if Current_Angle /= Center and then not Stop_Requested then
            Adaptive_Motion.Aim (Center);
            Current_Angle := Center;
            Center_Ready_At := Clock + Milliseconds (500);
         end if;
      end Recenter;
      function Read_Guard return Snapshot is
         S : Snapshot;
      begin
         -- The side sensors do not move with the front servo. Keep all three
         -- samples per sensor, using the settling interval for useful work.
         S.Left := Filtered (Left);
         S.Right := Filtered (Right);
         if Stop_Requested then return (others => 0); end if;
         delay until Center_Ready_At;
         if Stop_Requested then return (others => 0); end if;
         S.Front := Filtered (Front);
         if Pivot_Side_Too_Close (S.Left) then
            Show_Blocker ("L", S.Left);
         elsif Pivot_Side_Too_Close (S.Right) then
            Show_Blocker ("R", S.Right);
         elsif not Forward_Clear (S.Front, Forward_Stop_Distance) then
            Show_Blocker ("FRONT", S.Front);
         end if;
         if (Valid (S.Front) and then S.Front <= Forward_Stop_Distance)
           or else (Valid (S.Left) and then S.Left <= Side_Distance)
           or else (Valid (S.Right) and then S.Right <= Side_Distance)
         then
            Need_Measured_Exit := True;
         end if;
         if Need_Measured_Exit then
            Remember_Wall (Left, S.Left);
            Remember_Wall (Right, S.Right);
         end if;
         Adaptive_Proximity.State.Observe (S.Front);
         Put_Line ("SCAN GUARD LEFT " & Boolean'Image
                     (Adaptive_Scan_Policy.Rotation_Clear (S, Left, Allow_Open => True))
                   & " RIGHT " & Boolean'Image
                     (Adaptive_Scan_Policy.Rotation_Clear (S, Right, Allow_Open => True)));
         return S;
      end Read_Guard;
      procedure Point (Angle : Natural; Value : out Distance;
                       Sample_Started_Ms : out Natural) is
      begin
         if Stop_Requested then
            Value := 0; Sample_Started_Ms := Now_Ms; return;
         end if;
         if not Scanning_Shown then
            Adaptive_Display.Show_Status ("STATUS: SCAN");
            Scanning_Shown := True;
         end if;
         Adaptive_Proximity.State.Observe (0); -- angled rays are not front clearance
         Adaptive_Motion.Aim (Angle);
         Current_Angle := Angle;
         -- Keep the old settling allowance until the SG90 slew is measured.
         delay 0.5;
         Sample_Started_Ms := Now_Ms;
         Value := Filtered (Front);
         Put_Line ("SCAN ANGLE" & Natural'Image (Angle)
                   & (if Value = Open_Range then " OPEN"
                      elsif Value = 0 then " UNKNOWN"
                      else " CM" & Distance'Image (Value)));
      end Point;
      procedure Report_Reject
        (Direction : Choice; Reason : Adaptive_Scan_Policy.Scan_Rejection) is
      begin
         Put_Line ("SCAN REJECT " & Choice'Image (Direction) & " "
                   & Adaptive_Scan_Policy.Scan_Rejection'Image (Reason));
      end Report_Reject;
      package Search is new Adaptive_Quick_Scan
        (Recenter, Point, Read_Guard, Now_Ms, Stop_Requested, Report_Reject,
         Front_Limit => Forward_Stop_Distance, Wall_Pivot_Enabled => True);
      Result : Search.Scan_Result;
   begin
      Turn_Deadline := Time_First;
      Pivot_Direction := Blocked;
      Wall_Pivot_Selected := False;
      Adaptive_Motion.Stop;
      Adaptive_Motion.Aim (Center);
      Center_Ready_At := Clock + Milliseconds (500);
      Result := Search.Find (Previous, Allow_Straight and then not Need_Measured_Exit,
                             Wall_Direction, Try_Wall => Wall_Steps < Wall_Step_Count'Last,
                             Avoid_Side => Closing_Side);
      Pivot_Direction := Result.Direction;
      Pivot_Guard := Result.Pivot_Guard;
      Wall_Pivot_Selected := Result.Wall_Pivot;
      Wall_Exit_Selected := Result.Wall_Exit;
      if Wall_Pivot_Selected then
         Need_Measured_Exit := True;
         Put_Line ("WALL PIVOT " & Choice'Image (Result.Direction));
      end if;
      if Result.Direction in Left | Right then
         Turn_Deadline := Started + Milliseconds (Result.Oldest_Pair_Ms)
           + Milliseconds (Adaptive_Scan_Policy.Max_Pair_Age_Ms);
      elsif Result.Direction = Blocked then
         Adaptive_Display.Show_Status ("STATUS: STOP");
      end if;
      Adaptive_Display.Show_Direction
        ((case Result.Direction is
             when Left => 'L', when Right => 'R',
             when Straight => 'F', when Blocked => 'S'));
      Put_Line ("SCAN END POINTS" & Natural'Image (Result.Points)
                & " EXPIRED" & Natural'Image (Result.Expired_Pairs)
                & " ELAPSED_MS" & Natural'Image (Now_Ms)
                & " CHOICE " & Choice'Image (Result.Direction));
      return Result.Direction;
   end Scan_Path;
   function Monitor (Turning, Cruising : Boolean) return Boolean is
      Wall_Rotation : constant Boolean := Turning and then Wall_Pivot_Selected
        and then Adaptive_Safety.Motion_Commanded;
      Wall_Monitor_Sweeps : constant := 3;
      Left_Close : constant Boolean := Valid (Pivot_Guard.Left)
        and then Pivot_Guard.Left <= Wall_Release_Side_Distance;
      Right_Close : constant Boolean := Valid (Pivot_Guard.Right)
        and then Pivot_Guard.Right <= Wall_Release_Side_Distance;
      Close_Wall_Turn : constant Boolean := Turning and then Wall_Pivot_Selected
        and then (Left_Close or else Right_Close);
      Near_Sensor : constant Sensor :=
        (if Left_Close and then (not Right_Close or else Pivot_Guard.Left <= Pivot_Guard.Right)
         then Left else Right);
      Far_Sensor : constant Sensor := (if Near_Sensor = Left then Right else Left);

      function Stop_Pending return Boolean is
      begin
         if Adaptive_Safety.Stop_Requested then
            Adaptive_Motion.Stop;
            return True;
         end if;
         return False;
      end Stop_Pending;

      function Check (Which : Sensor; View : Choice := Straight) return Boolean is
         Confirm_Exit : constant Boolean := Which = Front and then not Turning
           and then not Cruising and then Need_Measured_Exit;
         Side : constant Side_Choice := (if Which = Left then Left else Right);
         Require_Measured : constant Boolean := (not Short_Pass and then
           (Confirm_Exit or else (Which = Front and then not Turning and then Pass_Side /= Blocked)))
           or else (Turning and then
                      (not Wall_Pivot_Selected
                       or else (Which = Front and then not (Wall_Exit_Selected or Wall_Rotation))
                       or else (Which = Left and then Left_Close)
                       or else (Which = Right and then Right_Close)));
         Limit : constant Natural :=
           (if Turning and then Which /= Front then
                Adaptive_Scan_Policy.Pivot_Side_Limit (Pivot_Direction, Side)
            elsif Turning then Turn_Distance
            elsif Which /= Front then Side_Distance
            elsif Confirm_Exit or else Short_Pass then Exit_Distance
            elsif View = Straight then Forward_Stop_Distance
            else Corner_Stop_Distance);
         D : Distance;
         Lost_Near_Echo : Boolean := False;
         Entering_Near, Closing_Near : Boolean := False;
      begin
         if Stop_Pending then return False; end if;
         D := Raw (Which);
         if Stop_Pending then return False; end if;
         if Which /= Front and then not Turning then
            declare
               Reading : Side_Reading renames Side_Readings (Side);
            begin
               if Valid (D) and then D <= Side_Approach_Distance then
                  Entering_Near := Cruising and then
                    Forward_Clear (Reading.Last, Side_Approach_Distance + Side_Approach_Drop);
                  -- Keep the widest recent gap in this heading across
                  -- short steps to notice a steady approach of a few cm.
                  Closing_Near := Cruising and then Reading.Approach_Reference >= Approach_Reference_Min
                    and then D + Side_Approach_Drop <= Reading.Approach_Reference;
                  Reading.Approach_Reference := Distance'Max (Reading.Approach_Reference, D);
               elsif not Valid (D) or else D > Side_Approach_Distance + Side_Approach_Drop then
                  Reading.Approach_Reference := 0;
               end if;
               Reading.Last := D;
            end;
         end if;
         if Which /= Front and then (Need_Measured_Exit
                                    or else (not Turning and then Valid (D) and then D <= Side_Distance))
         then
            Remember_Wall (Side, D);
         end if;
         if not Turning and then Which = Front and then View in Forward_View then
            Lost_Near_Echo := not Valid (D) and then Near_Echo (View);
            if Valid (D) then Near_Echo (View) := D <= Exit_Distance; end if;
         end if;
         -- Keep measuring any side where the stationary scan saw a close
         -- object. A lost echo there cannot justify continuing the pivot.
         if Entering_Near or else Closing_Near or else Lost_Near_Echo
           or else not (if not Turning and then Which /= Front
                        then Forward_Side_Clear (Side, D)
                        elsif Require_Measured then Clear (D, Limit)
                        else Forward_Clear (D, Limit))
         then
            Adaptive_Motion.Stop;
            if Closing_Near then Closing_Side := Side; end if;
            if Entering_Near or else Closing_Near
              or else Pass_Side /= Blocked or else Leaving_Wall or else Lost_Near_Echo
              or else (Valid (D) and then D <= Limit)
            then
               Need_Measured_Exit := True;
            end if;
            Pass_Side := Blocked;
            Short_Pass := False;
            Leaving_Wall := False;
            if not Turning then
               Show_Blocker ((if Which = Left then "L" elsif Which = Right then "R"
                              elsif View = Left then "CL" elsif View = Right then "CR"
                              else "FRONT"), D);
            end if;
            if Which = Front and then View = Straight then
               Adaptive_Proximity.State.Observe (D);
            end if;
            Put_Line ("MOTION STOP "
                      & (if View = Straight then Sensor'Image (Which)
                         else "CORNER " & Choice'Image (View))
                      & (if Closing_Near then " CLOSING CM" & Distance'Image (D)
                         elsif Entering_Near then " NEAR CM" & Distance'Image (D)
                         elsif Lost_Near_Echo then " LOST NEAR ECHO"
                         elsif D = Open_Range then " OPEN; CLEARANCE NOT VERIFIED"
                         elsif D = 0 then " UNKNOWN"
                         else " CM" & Distance'Image (D)));
            return False;
         end if;
         if not Turning and then Which /= Front and then Pass_Side = Side then
            Pass_Reference := Distance'Max (Pass_Reference, D);
            if D > Wall_Release_Side_Distance and then not Short_Pass then
               Pass_Side := Blocked;
               Seen_Wall (Side) := False;
            end if;
         end if;
         if Which = Front and then View = Straight then
            Adaptive_Proximity.State.Observe (D);
         end if;
         return True;
      end Check;

      View : Choice;
      Ready_At, Now, Wake_At : Time;
      First_Side : constant Sensor := (if Next_View mod 2 = 0 then Right else Left);
      Other_Side : constant Sensor := (if First_Side = Right then Left else Right);
   begin
      if Cruising and then Short_Pass then
         declare
            Near_Side : constant Sensor := (if Pass_Side = Left then Left else Right);
         begin
            -- The servo is still centered from preflight. Stop after one
            -- side/front/side sweep, then recheck both corners at rest.
            if not (Check (Near_Side) and then Check (Front) and then Check (Near_Side)) then
               return False;
            end if;
            Adaptive_Motion.Stop;
            Need_Measured_Exit := True;
            Pass_Side := Blocked;
            Short_Pass := False;
            return False;
         end;
      elsif Close_Wall_Turn then
         -- Use one sweep close to a wall. Check the nearer side twice.
         return Check (Near_Sensor) and then Check (Far_Sensor)
           and then Check (Front) and then Check (Near_Sensor);
      elsif not Cruising then
         -- A wall turn holds the same motor command for three monitored
         -- sweeps before the controller stops and reassesses forward travel.
         for Sweep in 1 .. (if Wall_Rotation then Wall_Monitor_Sweeps else 1) loop
            if not (Check (Front) and then Check (Left)
                    and then Check (Front) and then Check (Right))
            then
               return False;
            end if;
         end loop;
         return True;
      end if;

      if Stop_Pending then return False; end if;
      View := Cruise_Views (Next_View);
      Adaptive_Motion.Aim (View_Angle (View));
      -- Sample both sides while the servo settles so a narrowing gap is
      -- seen in every sweep, regardless of which front beam is next.
      Ready_At := Clock + Milliseconds (150);
      if not (Check (First_Side) and then Check (Other_Side)) then
         return False;
      end if;
      loop
         if Stop_Pending then return False; end if;
         Now := Clock;
         exit when Now >= Ready_At;
         Wake_At := Now + Milliseconds (10);
         delay until (if Wake_At < Ready_At then Wake_At else Ready_At);
      end loop;
      Next_View := (if Next_View = Cruise_Index'Last then Cruise_Index'First
                    else Next_View + 1);
      if not Check (Front, View) then return False; end if;
      if Leaving_Wall and then Next_View = Cruise_Index'First and then Pass_Side = Blocked then
         Leaving_Wall := False;
         Seen_Wall := (others => False);
      end if;
      return True;
   end Monitor;

   function Monitor_Motion (Turning : Boolean := False) return Boolean is
      Safe : constant Boolean := Monitor (Turning, Cruising => False);
   begin
      if Safe and then not Turning and then not Adaptive_Safety.Motion_Commanded then
         -- Only the stopped forward preflight consumes the clearance check.
         if Need_Measured_Exit then Near_Echo := (others => False); end if;
         Leaving_Wall := Need_Measured_Exit;
         Need_Measured_Exit := False;
         Closing_Side := Blocked;
         Wall_Direction := Blocked;
         Wall_Steps := 0;
         Pivot_Direction := Blocked;
         Pivot_Guard := (others => 0);
         Turn_Deadline := Time_First;
      end if;
      return Safe;
   end Monitor_Motion;

   function Monitor_Cruise return Boolean is
     (Monitor (Turning => False, Cruising => True));
end Adaptive_Navigation;
