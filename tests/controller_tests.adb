with Ada.Text_IO; use Ada.Text_IO;
with Ada.Exceptions;
with Adaptive_Controller;
with Adaptive_Fault_Handler;
with Adaptive_Errors; use Adaptive_Errors;
with Adaptive_Policy; use Adaptive_Policy;
with Adaptive_FSM; use Adaptive_FSM;
procedure Controller_Tests is
   Checks : Natural := 0;
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if not Condition then raise Program_Error with Name; end if;
      Checks := Checks + 1;
   end Check;
   type Scenario is
     (Idle, Clear_Cruise, Cruise_Obstacle, Left_Turn, Right_Turn,
      Straight_After_Scan, Blocked_Scan, Changed_Turn_Guard,
      No_Pre_Permit, No_Post_Permit, Stop_In_Read, Stop_In_Monitor,
      Worker_Fails, Drive_Fails, Secondary_Stop_Fails, Stop_Before_Arm,
      Init_Motor_Fails, Init_Display_Fails, No_Initialize, Double_Initialize,
      Expired_Before_Turn, Expired_In_Monitor);

   procedure Run (Test : Scenario) is
      Start_Flag, Stop_Flag, Worker_Failure, Moving, Centered : Boolean := False;
      Permit, Fail_Drive, Fail_Stop, Stop_Read, Stop_Monitor : Boolean := False;
      Init_Stage, Stop_Calls, Drive_Calls, Monitor_Calls, Fail_Monitor_At : Natural := 0;
      Frame : Snapshot := (100, 40, 40);
      Selected : Choice := Left;
      Last_Drive : Choice := Blocked;
      Fresh : Boolean := True;
      procedure Init (Stage : Positive) is
      begin
         Check (Init_Stage = Stage - 1, "ordered startup");
         Init_Stage := Stage;
         if (Test = Init_Motor_Fails and Stage = 3)
           or (Test = Init_Display_Fails and Stage = 4)
         then raise Program_Error with "injected initialization error"; end if;
      end Init;
      procedure Init_Lights is begin Init (1); end Init_Lights;
      procedure Init_Safety is begin Init (2); end Init_Safety;
      procedure Init_Motion is begin Init (3); end Init_Motion;
      procedure Init_Display is begin Init (4); end Init_Display;
      procedure Stop is
      begin
         Stop_Calls := Stop_Calls + 1; Permit := False;
         if Fail_Stop then raise Motor_Bus_Error with "injected stop error"; end if;
         Moving := False;
      end Stop;
      procedure Aim is
      begin
         Check (not Moving, "servo only while stopped"); Centered := True; Permit := False;
      end Aim;
      procedure Drive (Direction : Choice) is
      begin
         Check (Init_Stage = 4 and Start_Flag and not Stop_Flag, "initialized and armed drive");
         Check (Permit, "live monitor is last operation before drive");
         Drive_Calls := Drive_Calls + 1; Last_Drive := Direction;
         Moving := True; Permit := False;
         if Fail_Drive then
            Fail_Stop := Test = Secondary_Stop_Fails;
            raise Motor_Bus_Error with "injected drive error";
         end if;
      end Drive;
      function Read_Sensors return Snapshot is
      begin
         Check (not Moving and Centered, "filtered guard only while stopped and centered");
         if Stop_Read then Stop_Flag := True; end if;
         return Frame;
      end Read_Sensors;
      function Scan return Choice is
      begin
         Check (not Moving, "scan while stopped"); Centered := True; return Selected;
      end Scan;
      function Monitor (Turning : Boolean := False) return Boolean is
      begin
         Monitor_Calls := Monitor_Calls + 1;
         if Moving and Turning then
            Check (Last_Drive in Left | Right, "turn monitor follows turn command");
         end if;
         if Stop_Monitor then Stop_Flag := True; end if;
         Permit := Monitor_Calls /= Fail_Monitor_At
           and then (not Turning or else Turn_Safe (Frame));
         if Test = Expired_In_Monitor and Turning then Fresh := False; end if;
         return Permit;
      end Monitor;
      function Turn_Evidence_Fresh return Boolean is (Fresh);
      function Start_Requested return Boolean is (Start_Flag);
      function Stop_Requested return Boolean is (Stop_Flag);
      function Lights_Failed return Boolean is (Worker_Failure);
      procedure Show_Direction (Direction : Character) is
         pragma Unreferenced (Direction);
      begin
         Check (not Moving, "no display work during motion"); Permit := False;
      end Show_Direction;
      procedure Text (Message : String) is
         pragma Unreferenced (Message);
      begin
         Check (not Moving, "no text IO during motion"); Permit := False;
      end Text;
      procedure Pause (Milliseconds : Positive) is
         pragma Unreferenced (Milliseconds);
      begin
         Check (not Moving, "no stationary delay during motion"); Permit := False;
      end Pause;
      procedure Latch is begin Stop_Flag := True; end Latch;
      procedure Fault_Log (Message : String) is
         pragma Unreferenced (Message);
      begin null; end Fault_Log;
      package App is new Adaptive_Controller
        (Init_Lights, Init_Safety, Init_Motion, Init_Display, Stop, Aim, Drive,
         Read_Sensors, Scan, Turn_Evidence_Fresh, Monitor, Start_Requested, Stop_Requested,
         Lights_Failed, Show_Direction, Text, Text, Pause);
      package Boundary is new Adaptive_Fault_Handler (Latch, Stop, Fault_Log);
      use type Boundary.Stop_Result;
      procedure Expect_Fault (Expected : Fault_Code) is
         Raised : Boolean := False;
         Before_Drives, Before_Stops : Natural;
      begin
         begin App.Step;
         exception when E : others => Raised := True; Boundary.Handle (E); end;
         Check (Raised and App.Current_State = Fault and not App.Is_Armed,
                "controller latches fault before propagation");
         Check (Boundary.Status.Primary = Expected, "outer boundary preserves cause");
         Before_Drives := Drive_Calls; Before_Stops := Stop_Calls;
         Start_Flag := True; Stop_Flag := False; -- attempted fixture recovery
         begin App.Step;
         exception when E : others => Boundary.Handle (E); end;
         Check (Drive_Calls = Before_Drives and Stop_Calls = Before_Stops,
                "no restart or stop retry storm after latched fault");
      end Expect_Fault;
      Raised : Boolean := False;
      Before : Natural;
   begin
      if Test = No_Initialize then Expect_Fault (Program_Fault); return; end if;
      begin App.Initialize;
      exception when E : others => Raised := True; Boundary.Handle (E); end;
      if Test in Init_Motor_Fails | Init_Display_Fails then
         Check (Raised and App.Current_State = Fault and Drive_Calls = 0, "failed startup inhibits drive");
         Check (Boundary.Status.Primary = Program_Fault, "startup cause preserved");
         Before := Init_Stage;
         begin App.Initialize; exception when others => null; end;
         Check (Init_Stage = Before, "failed startup cannot be retried");
         return;
      end if;
      Check (not Raised and not App.Is_Armed, "startup never arms automatically");
      if Test = Double_Initialize then
         begin App.Initialize; exception when E : others => Boundary.Handle (E); end;
         Check (App.Current_State = Fault and Drive_Calls = 0, "repeat init rejected"); return;
      elsif Test = Idle then
         for I in 1 .. 10 loop App.Step; end loop;
         Check (Drive_Calls = 0 and Stop_Calls = 0 and not App.Is_Armed,
                "idle waits without any repeated motor bus traffic"); return;
      elsif Test = Stop_Before_Arm then
         Stop_Flag := True; Expect_Fault (Stop_Latch_Fault);
         Check (Drive_Calls = 0, "stop before arm prevents drive"); return;
      end if;
      Start_Flag := True; App.Step;
      Check (App.Is_Armed and App.Current_State = Verify, "A enables initial verification");
      if Test = Stop_In_Read then Stop_Read := True; Expect_Fault (Stop_Latch_Fault); return;
      elsif Test = Stop_In_Monitor then Stop_Monitor := True; Expect_Fault (Stop_Latch_Fault); return;
      elsif Test in Drive_Fails | Secondary_Stop_Fails then
         Fail_Drive := True; Expect_Fault (Motor_Bus_Fault);
         Check (Boundary.Status.Stop_Command = (if Test = Secondary_Stop_Fails then Boundary.Failed else Boundary.Acknowledged),
                "secondary stop result is explicit"); return;
      elsif Test = No_Pre_Permit then
         Fail_Monitor_At := 1; App.Step;
         Check (Drive_Calls = 0 and App.Current_State = Stopped, "no drive without pre-motion permit"); return;
      end if;
      if Test in Clear_Cruise | Cruise_Obstacle | Worker_Fails then
         App.Step;
         Check (App.Current_State = Cruise and Moving and Drive_Calls = 1, "verified cruise starts");
         if Test = Worker_Fails then Worker_Failure := True; Expect_Fault (Lights_Fault); return;
         elsif Test = Cruise_Obstacle then
            Fail_Monitor_At := Monitor_Calls + 1; App.Step;
            Check (not Moving and App.Current_State = Stopped, "cruise obstacle stops immediately");
         else
            Before := Stop_Calls;
            for I in 1 .. 10 loop App.Step; end loop;
            Check (Drive_Calls = 1 and Stop_Calls = Before and Moving,
                   "clear cruise has no stop/start cycling");
         end if;
         return;
      end if;
      Frame := (30, 40, 40); App.Step;
      Check (App.Current_State = Adaptive_FSM.Scan and Drive_Calls = 0, "obstacle triggers stopped scan");
      if Test = Right_Turn then Selected := Right;
      elsif Test = Straight_After_Scan then Selected := Straight;
      elsif Test = Blocked_Scan then Selected := Blocked; end if;
      App.Step;
      if Test = Blocked_Scan then
         Check (App.Current_State = Stopped and not Moving, "blocked scan stays stopped"); return;
      elsif Test = Straight_After_Scan then
         Frame := (100, 40, 40); App.Step;
         Check (Last_Drive = Straight and Moving, "fresh recheck resumes straight"); return;
      elsif Test = Changed_Turn_Guard then
         Frame.Left := 0; App.Step;
         Check (Drive_Calls = 0 and not Moving, "changed guard cancels selected turn"); return;
      elsif Test in Expired_Before_Turn | Expired_In_Monitor then
         Fresh := Test /= Expired_Before_Turn;
         App.Step;
         Check (Drive_Calls = 0 and App.Current_State = Stopped and not Moving,
                "evidence expiring before or during preflight cannot grant drive"); return;
      elsif Test = No_Post_Permit then Fail_Monitor_At := 2; end if;
      App.Step;
      Check (Drive_Calls = 1 and Last_Drive = Selected and not Moving, "turn is monitored then stopped");
      Check (App.Current_State = (if Test = No_Post_Permit then Stopped else Verify), "turn must reverify");
   end Run;
begin
   for Test in Scenario loop Run (Test); end loop;
   Put_Line ("PASS" & Natural'Image (Checks) & " integrated controller checks");
end Controller_Tests;
