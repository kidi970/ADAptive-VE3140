with Adaptive_Policy; use Adaptive_Policy;
package Adaptive_Navigation is
   function Scan_Path return Choice;
   function Turn_Evidence_Fresh return Boolean;
   function Monitor_Motion (Turning : Boolean := False) return Boolean;
end Adaptive_Navigation;
