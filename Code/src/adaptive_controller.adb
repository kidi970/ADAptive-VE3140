with Adaptive_Errors;
package body Adaptive_Controller is
   Current : State := Stopped;
   Direction : Choice := Blocked;
   Attempted, Initialized, Armed : Boolean := False;
   function Current_State return State is (Current);
   function Is_Armed return Boolean is (Armed);
   procedure Check_Stop is
   begin
      if Lights_Failed then
         raise Adaptive_Errors.Lights_Task_Error with "Lamp task failed";
      elsif Stop_Requested then
         raise Adaptive_Errors.Stop_Latched_Error with "Stop requested";
      end if;
   end Check_Stop;
   procedure Initialize is
   begin
      if Attempted or Current = Fault then
         raise Program_Error with "Controller initialization is one-shot";
      end if;
      Attempted := True;
      Log ("ADAptive CONTROLLER START");
      Log ("STARTUP LIGHTS P0/P12/P16"); Initialize_Lights;
      Log ("STARTUP SAFETY"); Initialize_Safety;
      Log ("STARTUP MOTOR"); Initialize_Motion;
      Log ("STARTUP DISPLAY"); Initialize_Display;
      Check_Stop;
      Show_Direction ('S'); Show_Status ("STATUS: STOP");
      Log ("READY: PRESS A TO START; B LATCHES STOP UNTIL RESET");
      Initialized := True;
   exception
      when others => Current := Fault; Armed := False; raise;
   end Initialize;
   procedure Reject_Motion is
   begin
      Stop_Motors;
      Current := Stopped;
      Show_Direction ('S');
   end Reject_Motion;
   procedure Step is
      S : Snapshot;
      Safe : Boolean;
   begin
      if not Initialized then
         raise Program_Error with "Controller not initialized";
      elsif Current = Fault then
         raise Adaptive_Errors.Stop_Latched_Error with "Controller fault latched";
      end if;
      Check_Stop;
      if not Armed then
         if not Start_Requested then Pause (20); return; end if;
         Armed := True;
         Log ("ARMED BY BUTTON A");
      end if;
      case Current is
         when Stopped =>
            Stop_Motors;
            Show_Direction ('S'); Show_Status ("STATUS: STOP");
            Pause (300);
            Current := Next_State (Current, Recheck);
         when Verify =>
            Stop_Motors; Aim_Center; Pause (500);
            S := Read_Sensors;
            Check_Stop;
            if Forward_Safe (S) then
               Show_Direction ('F'); Show_Status ("STATUS: FORWARD");
               if Monitor_Motion then
                  Check_Stop;
                  Drive (Straight);
                  Current := Next_State (Current, Clear_Path);
               else Reject_Motion; end if;
            else Current := Next_State (Current, Unsafe_Path); end if;
         when Cruise =>
            if not Monitor_Motion then Reject_Motion;
            else Check_Stop; end if;
         when Scan =>
            Direction := Scan_Path;
            Check_Stop;
            case Direction is
               when Straight => Current := Next_State (Current, Scan_Straight);
               when Right | Left => Current := Next_State (Current, Scan_Turn);
               when Blocked => Current := Next_State (Current, Scan_Blocked);
            end case;
         when Turn =>
            Stop_Motors;
            -- Scan_Path returns centered with a new guard. Avoid repeating
            -- the servo delay and filtered scan; monitor all live sensors
            -- and check the original side evidence immediately before drive.
            Check_Stop;
            if Direction in Left | Right and then Turn_Evidence_Fresh then
               Show_Direction ((if Direction = Left then 'L' else 'R'));
               Show_Status ("STATUS: TURN");
               if Monitor_Motion (Turning => True) and then Turn_Evidence_Fresh then
                  Check_Stop;
                  Drive (Direction);
                  Safe := Monitor_Motion (Turning => True);
                  Stop_Motors;
                  Check_Stop;
                  Current := Next_State (Current, (if Safe then Turn_Done else Unsafe_Path));
               else Reject_Motion; end if;
            else Reject_Motion; end if;
         when Fault => raise Adaptive_Errors.Stop_Latched_Error;
      end case;
   exception
      when others => Current := Fault; Armed := False; raise;
   end Step;
end Adaptive_Controller;
