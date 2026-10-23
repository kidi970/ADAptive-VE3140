with Adaptive_Policy; use Adaptive_Policy;
package Adaptive_Navigation is
   function Scan_Path return Choice;
   function Monitor_Motion (Turning : Boolean := False) return Boolean;
end Adaptive_Navigation;
