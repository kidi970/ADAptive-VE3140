with Adaptive_Sensors; use Adaptive_Sensors;
with Adaptive_Motion;
with Adaptive_Display;
with Adaptive_FSM;
with Adaptive_Safety;
with MicroBit.Console; use MicroBit.Console;
package body Adaptive_Navigation is
   Previous : Choice := Blocked;
   Count : Natural := 0;
   function Scan_Path return Choice is
      Five : Distances (1 .. 5);
      Seven : Distances (1 .. 7);
      S : Snapshot;
      Result : Choice;
      Accepted : Boolean;
      procedure Point (Angle : Natural; D : out Distance) is
      begin
         if Adaptive_Safety.Stop_Requested then D := 0; return; end if;
         Adaptive_Motion.Aim (Angle);
         delay 0.5;
         D := Filtered (Front);
         Put_Line ("SCAN ANGLE" & Natural'Image (Angle)
                   & " CM" & Distance'Image (D));
      end Point;
   begin
      Adaptive_Motion.Stop;
      Adaptive_Display.Show_Status ("STATUS: SCAN");
      for I in Five'Range loop Point (48 + 12 * I, Five (I)); end loop;
      Adaptive_Motion.Aim (Center); delay 0.5;
      S := Read_All;
      Result := Select_Five (Five, S);
      if Result /= Blocked then
         Previous := Blocked; Count := 0;
         return Result;
      end if;
      Put_Line ("EXTENDED 7P START");
      for I in Seven'Range loop Point (44 + 10 * I, Seven (I)); end loop;
      Adaptive_Motion.Aim (Center); delay 0.5;
      S := Read_All;
      Result := Select_Seven (Seven, S, Five (3));
      if Result = Blocked and Adaptive_Motion.Outer_Angles_Verified then
         declare
            Outer_Right, Outer_Left : Distance;
         begin
            Point (34, Outer_Right); Point (134, Outer_Left);
            Put_Line ("1P RIGHT" & Distance'Image (Outer_Right)
                      & " LEFT" & Distance'Image (Outer_Left));
            -- A single ray cannot replace a rejected corridor.
         end;
      elsif Result = Blocked then
         Put_Line ("1P SKIPPED: MECHANICAL LIMITS UNVERIFIED");
      end if;
      Adaptive_Motion.Aim (Center); delay 0.5;
      Adaptive_FSM.Confirm (Result, Previous, Count, Accepted);
      Put_Line ("7P CHOICE " & Choice'Image (Result));
      if Accepted then return Result; else return Blocked; end if;
   end Scan_Path;
   function Monitor_Motion (Turning : Boolean := False) return Boolean is
      D : Distance;
      function Check (Which : Sensor) return Boolean is
         Limit : Natural := Side_Distance;
      begin
         if Adaptive_Safety.Stop_Requested then
            Adaptive_Motion.Stop;
            return False;
         end if;
         if Turning then Limit := Turn_Distance;
         elsif Which = Front then Limit := Stop_Distance; end if;
         D := Raw (Which);
         if not Clear (D, Limit) then
            -- Stop before logging, display updates, or any further sample.
            Adaptive_Motion.Stop;
            Put_Line ("MOTION STOP " & Sensor'Image (Which)
                      & " CM" & Distance'Image (D));
            return False;
         end if;
         return True;
      end Check;
   begin
      -- Front is revisited between the two side sensors (nominal 130 ms).
      return Check (Front) and then Check (Left)
        and then Check (Front) and then Check (Right);
   end Monitor_Motion;
end Adaptive_Navigation;
