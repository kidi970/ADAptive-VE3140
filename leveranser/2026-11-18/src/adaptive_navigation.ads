with Adaptive_Policy; use Adaptive_Policy;
package Adaptive_Navigation is
   function Check_Forward_Corners (Frame : Snapshot) return Boolean;
   function Scan_Path (Allow_Straight : Boolean := True) return Choice;
   function Turn_Evidence_Fresh return Boolean;
   procedure Note_Turn_Started (Direction : Choice);
   function Monitor_Motion (Turning : Boolean := False) return Boolean;
   function Monitor_Cruise return Boolean;
end Adaptive_Navigation;
