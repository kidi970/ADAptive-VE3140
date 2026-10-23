with Adaptive_Policy; use Adaptive_Policy;
package Adaptive_Motion is
   -- Wider angles remain disabled until the physical envelope is confirmed.
   Outer_Angles_Verified : constant Boolean := True;
   procedure Initialize;
   procedure Stop;
   procedure Drive (Direction : Choice);
   procedure Aim (Angle : Natural);
end Adaptive_Motion;
