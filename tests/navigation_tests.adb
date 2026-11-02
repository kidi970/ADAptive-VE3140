with Ada.Text_IO; use Ada.Text_IO;
with Adaptive_Motion;
with Adaptive_Navigation;
with Adaptive_Policy; use Adaptive_Policy;
with Adaptive_Safety; use Adaptive_Safety;
with Sensor_Fixture; use Sensor_Fixture;
with Adaptive_Sensors;
procedure Navigation_Tests is
   Checks : Natural := 0;
   Safe : Boolean;
   Selected : Choice;
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if not Condition then raise Program_Error with Name; end if;
      Checks := Checks + 1;
   end Check;
   procedure Begin_Drive is
   begin
      Stop_Requested := False;
      Values := (others => 100); Read_Count := 0; Stop_On_Read := 0;
      Front_Length := 0; Front_Index := 0;
      Request_Start;
      Adaptive_Motion.Initialize;
      Adaptive_Motion.Drive (Straight);
   end Begin_Drive;
begin
   Check (not Adaptive_Navigation.Turn_Evidence_Fresh, "no turn permission without a scan");
   Stop_Requested := True;
   Check (Adaptive_Sensors.Raw (Adaptive_Sensors.Front) = 0 and Read_Count = 0,
          "stopped acquisition never emits another trigger");
   Begin_Drive;
   Safe := Adaptive_Navigation.Monitor_Motion;
   Check (Safe and Motion_Commanded and Read_Count = 4, "clear cruise stays moving");
   for Failure_Read in 1 .. 4 loop
      Begin_Drive; Stop_On_Read := Failure_Read;
      Safe := Adaptive_Navigation.Monitor_Motion;
      Check (not Safe and Stop_Requested and not Motion_Commanded
             and Motor_Stop_Acknowledged, "stop during any read stops immediately");
      Check (Read_Count = Failure_Read, "no later reading after stop interrupt");
   end loop;
   Begin_Drive; Values (1) := 0;
   Safe := Adaptive_Navigation.Monitor_Motion;
   Check (not Safe and not Motion_Commanded and Read_Count = 1, "unknown front stops first");
   Begin_Drive; Values (2) := Side_Distance;
   Safe := Adaptive_Navigation.Monitor_Motion;
   Check (not Safe and not Motion_Commanded and Read_Count = 2, "side boundary stops");
   Begin_Drive; Values (8) := Turn_Distance;
   Safe := Adaptive_Navigation.Monitor_Motion (Turning => True);
   Check (not Safe and not Motion_Commanded and Read_Count = 4, "turn envelope boundary stops");
   Begin_Drive; Adaptive_Motion.Stop;
   Read_Count := 0; Values (1) := 30;
   Front_Length := 12; Front_Index := 0;
   Front_Sequence := (others => 30);
   Front_Sequence (4 .. 9) := (others => 150);
   Selected := Adaptive_Navigation.Scan_Path;
   Check (Selected = Right and Read_Count = 24 and not Motion_Commanded,
          "actual stopped scan retains all filtered samples and selects right");
   Check (History (1).Pin = 2 and History (1).Since_Servo_Aim < 0.5,
          "fixed side sensor uses front servo settling interval");
   for I in 1 .. Read_Count loop
      if History (I).Pin = 1 then
         Check (History (I).Since_Servo_Aim >= 0.499,
                "front sampling never starts before servo settling deadline");
      end if;
   end loop;
   Safe := Adaptive_Navigation.Monitor_Motion (Turning => True);
   Check (Safe and Adaptive_Navigation.Turn_Evidence_Fresh,
          "actual scan plus live preflight fits design evidence window on host");
   delay 2.1;
   Check (not Adaptive_Navigation.Turn_Evidence_Fresh, "scan permission expires without new evidence");
   Put_Line ("PASS" & Natural'Image (Checks) & " navigation checks (mock sensors/I2C)");
end Navigation_Tests;
