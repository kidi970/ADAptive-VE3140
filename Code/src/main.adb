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
with MicroBit.Console; use MicroBit.Console;
procedure Main is
   procedure Latch_Fault is
   begin
      Adaptive_Safety.Request_Stop;
      Adaptive_Lamp_Control.State.Latch_Fault;
   end Latch_Fault;
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
     (Latch_Fault, Adaptive_Motion.Stop, Put_Line);
   package App is new Adaptive_Controller
     (Adaptive_Lights.Initialize, Adaptive_Safety.Initialize,
      Adaptive_Motion.Initialize, Adaptive_Display.Initialize,
      Adaptive_Motion.Stop, Aim_Center, Adaptive_Motion.Drive,
      Adaptive_Sensors.Read_All, Adaptive_Navigation.Scan_Path,
      Adaptive_Navigation.Turn_Evidence_Fresh,
      Adaptive_Navigation.Monitor_Motion, Start_Requested, Stop_Requested,
      Adaptive_Lights.Failed, Adaptive_Display.Show_Direction,
      Adaptive_Display.Show_Status, Put_Line, Pause);
begin
   App.Initialize;
   loop App.Step; end loop;
exception
   when E : others =>
      Faults.Handle (E);
      loop delay 1.0; end loop;
end Main;
