with Adaptive_Policy; use Adaptive_Policy;
with Adaptive_FSM; use Adaptive_FSM;
generic
   with procedure Initialize_Lights;
   with procedure Initialize_Safety;
   with procedure Initialize_Motion;
   with procedure Initialize_Display;
   with procedure Stop_Motors;
   with procedure Aim_Center;
   with procedure Drive (Direction : Choice);
   with function Read_Sensors return Snapshot;
   with function Scan_Path return Choice;
   with function Turn_Evidence_Fresh return Boolean;
   with function Monitor_Motion (Turning : Boolean := False) return Boolean;
   with function Start_Requested return Boolean;
   with function Stop_Requested return Boolean;
   with function Lights_Failed return Boolean;
   with procedure Show_Direction (Direction : Character);
   with procedure Show_Status (Message : String);
   with procedure Log (Message : String);
   with procedure Pause (Milliseconds : Positive);
package Adaptive_Controller is
   -- One foreground owner. Injected hardware makes the real control flow
   -- testable through startup, cruise, scan, turn and fault without a car.
   procedure Initialize;
   procedure Step;
   function Current_State return State;
   function Is_Armed return Boolean;
   -- Fault is latched before propagation to the outer stop boundary.
   -- Initialize is one-shot; recovery requires a board reset, never a retry.
end Adaptive_Controller;
