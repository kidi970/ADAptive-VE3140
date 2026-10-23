with Adaptive_Policy; use Adaptive_Policy;
with Adaptive_FSM; use Adaptive_FSM;
with Adaptive_Sensors;
with Adaptive_Motion;
with Adaptive_Navigation;
with Adaptive_Display;
with Adaptive_Safety;
with MicroBit.Console; use MicroBit.Console;
with Ada.Exceptions;
procedure Main is
   Current : State := Stopped;
   Direction : Choice := Blocked;
   S : Snapshot;
   Safe : Boolean;
begin
   Put_Line ("ADAptive MODULAR START");
   Adaptive_Motion.Initialize;
   Adaptive_Safety.Initialize;
   Adaptive_Display.Initialize;
   Adaptive_Display.Show_Direction ('S');
   Adaptive_Display.Show_Status ("STATUS: STOP");
   delay 0.8;
   loop
      if Adaptive_Safety.Stop_Requested then
         Adaptive_Motion.Stop;
         Current := Fault;
      end if;
      if Current /= Cruise then Put_Line ("FSM " & State'Image (Current)); end if;
      case Current is
         when Stopped =>
            Adaptive_Motion.Stop;
            Adaptive_Display.Show_Direction ('S');
            Adaptive_Display.Show_Status ("STATUS: STOP");
            delay 0.3;
            Current := Next_State (Current, Recheck);
         when Verify =>
            Adaptive_Motion.Stop;
            Adaptive_Motion.Aim (Center); delay 0.5;
            S := Adaptive_Sensors.Read_All;
            Put_Line ("VERIFY FRONT" & Distance'Image (S.Front)
                      & " LEFT" & Distance'Image (S.Left)
                      & " RIGHT" & Distance'Image (S.Right));
            if Forward_Safe (S) then
               Adaptive_Display.Show_Direction ('F');
               Adaptive_Display.Show_Status ("STATUS: FORWARD");
               Current := Next_State (Current, Clear_Path);
               if Adaptive_Navigation.Monitor_Motion then
                  Put_Line ("MOTOR FORWARD: PWM 800");
                  Adaptive_Motion.Drive (Straight);
               else Current := Stopped; end if;
            else Current := Next_State (Current, Unsafe_Path); end if;
         when Cruise =>
            Safe := Adaptive_Navigation.Monitor_Motion;
            if not Safe then Current := Next_State (Current, Unsafe_Path); end if;
         when Scan =>
            Direction := Adaptive_Navigation.Scan_Path;
            case Direction is
               when Straight => Current := Next_State (Current, Scan_Straight);
               when Right | Left => Current := Next_State (Current, Scan_Turn);
               when Blocked => Current := Next_State (Current, Scan_Blocked);
            end case;
         when Turn =>
            Adaptive_Motion.Stop;
            Adaptive_Motion.Aim (Center); delay 0.5;
            S := Adaptive_Sensors.Read_All;
            if Turn_Safe (S) and Direction in Left | Right then
               Adaptive_Display.Show_Status ("STATUS: TURN");
               Put_Line ("MOTOR TURN REQUEST " & Choice'Image (Direction));
               if Adaptive_Navigation.Monitor_Motion (Turning => True) then
                  Adaptive_Motion.Drive (Direction);
                  Safe := Adaptive_Navigation.Monitor_Motion (Turning => True);
                  Adaptive_Motion.Stop;
                  if Safe then Current := Next_State (Current, Turn_Done);
                  else Current := Next_State (Current, Unsafe_Path); end if;
               else Current := Stopped; end if;
            else Current := Next_State (Current, Unsafe_Path); end if;
         when Fault => Adaptive_Motion.Stop; delay 0.5;
      end case;
   end loop;
exception
   when E : others =>
      begin Adaptive_Motion.Stop;
      exception when others => null; end;
      Put_Line ("FAULT LATCHED " & Ada.Exceptions.Exception_Name (E));
      loop delay 1.0; end loop;
end Main;
