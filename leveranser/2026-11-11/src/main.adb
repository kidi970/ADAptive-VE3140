with Adaptive_Policy; use Adaptive_Policy;
with Adaptive_FSM; use Adaptive_FSM;
with Adaptive_Sensors;
with Adaptive_Motion;
with Adaptive_Navigation;
with Adaptive_Display;
with Adaptive_Safety;
with Adaptive_Log; use Adaptive_Log;
with Adaptive_Lights;
with Adaptive_Lamp_Control;
with Adaptive_Lamp_Policy;
with Ada.Exceptions;
procedure Main is
   -- A requests a stationary forward check, without an initial sweep.
   Current : State := Verify;
   Direction : Choice := Blocked;
   S : Snapshot;
   Safe : Boolean;
begin
   Put_Line ("ADAptive ROOM RANGE 400 CM");
   Adaptive_Lights.Initialize;
   Adaptive_Safety.Initialize;
   Adaptive_Motion.Initialize;
   Adaptive_Sensors.Initialize;
   Adaptive_Display.Initialize;
   Adaptive_Display.Show_Direction ('S');
   Adaptive_Display.Show_Status ("STATUS: STOP");
   Adaptive_Lamp_Control.State.Set_Mode (Adaptive_Lamp_Policy.Parked);
   Put_Line ("Parked: A starts; B latches stop");
   while not Adaptive_Safety.Start_Requested
     and then not Adaptive_Safety.Stop_Requested
   loop
      delay 0.05;
   end loop;
   loop
      if Adaptive_Safety.Stop_Requested then
         Adaptive_Lamp_Control.State.Latch_Fault;
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
                  Adaptive_Motion.Drive (Straight);
                  Put_Line ("MOTOR FORWARD: PWM 800");
               else Current := Stopped; end if;
            else Current := Next_State (Current, Unsafe_Path); end if;
         when Cruise =>
            -- Keep the servo centered and monitor continuously. Monitor_Motion
            -- stops the motors before returning False on danger/unknown data.
            Safe := Adaptive_Navigation.Monitor_Motion;
            if not Safe then
               Current := Next_State (Current, Unsafe_Path);
            end if;
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
                  Adaptive_Display.Show_Direction
                    ((if Direction = Left then 'L' else 'R'));
                  Put_Line ("MOTOR TURN ACTIVE " & Choice'Image (Direction));
                  Safe := Adaptive_Navigation.Monitor_Motion (Turning => True);
                  Adaptive_Motion.Stop;
                  if Safe then Current := Next_State (Current, Turn_Done);
                  else Current := Next_State (Current, Unsafe_Path); end if;
               else Current := Stopped; end if;
            else
               Put_Line ("TURN REJECT FRONT" & Distance'Image (S.Front)
                         & " LEFT" & Distance'Image (S.Left)
                         & " RIGHT" & Distance'Image (S.Right));
               Current := Next_State (Current, Unsafe_Path);
            end if;
         when Fault => Adaptive_Motion.Stop; delay 0.5;
      end case;
   end loop;
exception
   when E : others =>
      Adaptive_Safety.Request_Stop;
      Adaptive_Lamp_Control.State.Latch_Fault;
      begin Adaptive_Motion.Stop;
      exception when others => null; end;
      Put_Line ("FAULT LATCHED " & Ada.Exceptions.Exception_Name (E));
      Put_Line ("FAULT DETAIL " & Ada.Exceptions.Exception_Message (E));
      loop delay 1.0; end loop;
end Main;
