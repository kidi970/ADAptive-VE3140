with Adaptive_Controller;
with Adaptive_Fault_Handler;
with Adaptive_Policy;
with Adaptive_Sensors;
with Adaptive_Motion;
with Adaptive_Navigation;
with Adaptive_Display;
with Adaptive_Safety;
with Adaptive_Lights;
with Adaptive_Lamp_Control;
with Adaptive_Errors;
with Adaptive_Lamp_Policy;
with Adaptive_Proximity;
with Adaptive_Log; use Adaptive_Log;
procedure Main is
   procedure Latch_Fault is
   begin
      Adaptive_Safety.Request_Stop;
   end Latch_Fault;
   procedure Show_Stopped
     (Cause : Adaptive_Errors.Fault_Code; Confirmed : Boolean) is
      use type Adaptive_Errors.Fault_Code;
   begin
      if Confirmed and then Cause = Adaptive_Errors.Stop_Latch_Fault then
         Adaptive_Lamp_Control.State.Set_Mode (Adaptive_Lamp_Policy.Braking);
         Adaptive_Display.Show_Direction ('S');
         Adaptive_Display.Show_Status ("STATUS: STOP");
      else
         Adaptive_Lamp_Control.State.Latch_Fault;
         Adaptive_Display.Show_Direction ('S');
         Adaptive_Display.Show_Status ("STATUS: FAULT");
      end if;
   end Show_Stopped;
   function Read_Sensors return Adaptive_Policy.Snapshot is
      S : constant Adaptive_Policy.Snapshot := Adaptive_Sensors.Read_All;
   begin
      Adaptive_Proximity.State.Observe (S.Front);
      return S;
   end Read_Sensors;
   procedure Aim_Center is
   begin
      Adaptive_Motion.Aim (Adaptive_Policy.Center);
   end Aim_Center;
   procedure Pause (Milliseconds : Positive) is
   begin
      delay Duration (Milliseconds) / 1_000.0;
   end Pause;
   function Start_Requested return Boolean is (Adaptive_Safety.Start_Requested);
   function Stop_Requested return Boolean is (Adaptive_Safety.Stop_Requested);
   package Faults is new Adaptive_Fault_Handler
     (Latch_Fault, Adaptive_Motion.Stop, Put_Line, Show_Stopped);
   package App is new Adaptive_Controller
     (Adaptive_Lights.Initialize, Adaptive_Safety.Initialize,
      Adaptive_Motion.Initialize, Adaptive_Display.Initialize,
      Adaptive_Motion.Stop, Aim_Center, Adaptive_Motion.Drive,
      Read_Sensors, Adaptive_Navigation.Check_Forward_Corners,
      Adaptive_Navigation.Scan_Path,
      Adaptive_Navigation.Turn_Evidence_Fresh,
      Adaptive_Navigation.Monitor_Motion, Adaptive_Navigation.Monitor_Cruise,
      Start_Requested, Stop_Requested,
      Adaptive_Lights.Failed, Adaptive_Display.Show_Direction,
      Adaptive_Display.Show_Status, Put_Line, Pause,
      Note_Turn_Started => Adaptive_Navigation.Note_Turn_Started);
begin
   Put_Line ("ADAptive OPEN SPACE 2026-11-17; COMPLETED_ECHO_ONLY; FALL=70MS; LED="
             & (if Adaptive_Lights.Powerbank_LED_Test then "ALWAYS_ON" else "SIGNALS")
             & "; AUDIO=BUILTIN; MOTORS=FR_RR_FL_RL; TURN=SWAPPED; PASS=STEP_OPEN; SIDE_WATCH=30; A=START B=STOP");
   App.Initialize;
   -- Retain a stopped snapshot for diagnostics before A. This does not
   -- authorize travel; the controller always takes fresh readings to drive.
   Put_Line ("PREARM SENSOR SNAPSHOT; MOTORS STOPPED");
   declare
      Initial : constant Adaptive_Policy.Snapshot := Adaptive_Sensors.Read_All;
      pragma Unreferenced (Initial);
   begin
      null;
   end;
   loop App.Step; end loop;
exception
   when E : others =>
      Faults.Handle (E);
      loop delay 1.0; end loop;
end Main;
