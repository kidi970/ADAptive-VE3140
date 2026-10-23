with MicroBit;         use MicroBit;
with MicroBit.Ultrasonic;
with MicroBit.DisplayRT;
with MicroBit.Types;   use MicroBit.Types;
with MicroBit.Console; use MicroBit.Console;
with MicroBit.I2C;
with HAL;              use HAL;
with HAL.I2C;          use HAL.I2C;
with MicroBit.MotorDriver;

procedure Main is
   package Front_Sensor is new MicroBit.Ultrasonic (MB_P13, MB_P1);

   -- Distance measurements from servo scanning
   Front_Distance : Distance_cm := 0;

   Distance_A     : Distance_cm := 0;
   Distance_Front : Distance_cm := 0;
   Distance_B     : Distance_cm := 0;

   -- Selected direction after scanning
   type Scan_Direction is (Side_A, Straight, Side_B, Blocked);

   Best_Direction : Scan_Direction := Blocked;
   -- Movement states
   type Movement_State is (Stop, Forward, Reverse_Drive, Scan, Turn, Verify);


   -- Current movement state
   Current_State : Movement_State := Stop;

   procedure Show_Direction (Direction : Character) is
      use MicroBit.DisplayRT;

      procedure Draw (Row : Coord; Pattern : String) is
      begin
         for X in Pattern'Range loop
            if Pattern (X) = '1' then
               Set (Coord (X - Pattern'First), Row);
            end if;
         end loop;
      end Draw;

   begin
      Clear;

      case Direction is
         when 'L'    =>
            Draw (0, "00100");
            Draw (1, "01000");
            Draw (2, "11111");
            Draw (3, "01000");
            Draw (4, "00100");

         when 'R'    =>
            Draw (0, "00100");
            Draw (1, "00010");
            Draw (2, "11111");
            Draw (3, "00010");
            Draw (4, "00100");

         when 'F'    =>
            Draw (0, "00100");
            Draw (1, "01110");
            Draw (2, "10101");
            Draw (3, "00100");
            Draw (4, "00100");

         when others =>
            Draw (0, "10001");
            Draw (1, "01010");
            Draw (2, "00100");
            Draw (3, "01010");
            Draw (4, "10001");
      end case;
   end Show_Direction;

   function State_Text (State : Movement_State) return String is
   begin
      case State is
         when Scan          =>
            return "SCAN";

         when Verify        =>
            return "VERIFY";

         when Stop          =>
            return "STOP";

         when Forward       =>
            return "FORWARD";

         when Reverse_Drive =>
            return "REVERSE";

         when Turn          =>
            return "TURN";
      end case;
   end State_Text;

   Reading_1, Reading_2, Reading_3 : Distance_cm := 0;
   Status                          : I2C_Status;

   Port : constant Any_I2C_Port := MicroBit.I2C.ControllerExt;

   procedure Send (Name : String; Data : I2C_Data) is
   begin
      Port.Master_Transmit (Addr => 16#78#, Data => Data, Status => Status);

      if Status /= Ok then
         Put_Line (Name & ": " & I2C_Status'Image (Status));
      end if;
   end Send;

   Zero_Block : constant I2C_Data (1 .. 17) := (1 => 16#40#, others => 16#00#);

   function Median (A, B, C : Distance_cm) return Distance_cm is
      function Valid (D : Distance_cm) return Boolean is
      begin
         return D >= 2 and then D <= 200;
      end Valid;

      function Close (X, Y : Distance_cm) return Boolean is
      begin
         return
           (X >= Y and then X - Y <= 15) or else (Y > X and then Y - X <= 15);
      end Close;

      Result : Distance_cm := 0;
   begin
      -- Require at least two valid, agreeing measurements.
      -- Use the lowest agreeing value conservatively.

      if Valid (A) and then Valid (B) and then Close (A, B) then
         Result := Distance_cm'Min (A, B);
      end if;

      if Valid (A) and then Valid (C) and then Close (A, C) then
         if Result = 0 then
            Result := Distance_cm'Min (A, C);
         else
            Result := Distance_cm'Min (Result, Distance_cm'Min (A, C));
         end if;
      end if;

      if Valid (B) and then Valid (C) and then Close (B, C) then
         if Result = 0 then
            Result := Distance_cm'Min (B, C);
         else
            Result := Distance_cm'Min (Result, Distance_cm'Min (B, C));
         end if;
      end if;

      return Result;
   end Median;

   procedure Draw_Char (C : Character) is
      Pixels : I2C_Data (1 .. 7) := (1 => 16#40#, others => 0);
   begin
      case C is
         when 'F'    =>
            Pixels (2 .. 6) := (16#7F#, 16#09#, 16#09#, 16#09#, 16#01#);

         when 'R'    =>
            Pixels (2 .. 6) := (16#7F#, 16#09#, 16#19#, 16#29#, 16#46#);

         when 'O'    =>
            Pixels (2 .. 6) := (16#3E#, 16#41#, 16#41#, 16#41#, 16#3E#);

         when 'N'    =>
            Pixels (2 .. 6) := (16#7F#, 16#02#, 16#04#, 16#08#, 16#7F#);

         when 'T'    =>
            Pixels (2 .. 6) := (16#01#, 16#01#, 16#7F#, 16#01#, 16#01#);

         when 'C'    =>
            Pixels (2 .. 6) := (16#3E#, 16#41#, 16#41#, 16#41#, 16#22#);

         when 'M'    =>
            Pixels (2 .. 6) := (16#7F#, 16#02#, 16#0C#, 16#02#, 16#7F#);

         when ':'    =>
            Pixels (2 .. 6) := (0, 16#36#, 16#36#, 0, 0);

         when '-'    =>
            Pixels (2 .. 6) := (8, 8, 8, 8, 8);

         when '0'    =>
            Pixels (2 .. 6) := (16#3E#, 16#51#, 16#49#, 16#45#, 16#3E#);

         when '1'    =>
            Pixels (2 .. 6) := (0, 16#42#, 16#7F#, 16#40#, 0);

         when '2'    =>
            Pixels (2 .. 6) := (16#42#, 16#61#, 16#51#, 16#49#, 16#46#);

         when '3'    =>
            Pixels (2 .. 6) := (16#21#, 16#41#, 16#45#, 16#4B#, 16#31#);

         when '4'    =>
            Pixels (2 .. 6) := (16#18#, 16#14#, 16#12#, 16#7F#, 16#10#);

         when '5'    =>
            Pixels (2 .. 6) := (16#27#, 16#45#, 16#45#, 16#45#, 16#39#);

         when '6'    =>
            Pixels (2 .. 6) := (16#3C#, 16#4A#, 16#49#, 16#49#, 16#30#);

         when '7'    =>
            Pixels (2 .. 6) := (16#01#, 16#71#, 16#09#, 16#05#, 16#03#);

         when '8'    =>
            Pixels (2 .. 6) := (16#36#, 16#49#, 16#49#, 16#49#, 16#36#);

         when '9'    =>
            Pixels (2 .. 6) := (16#06#, 16#49#, 16#49#, 16#29#, 16#1E#);

         when 'S'    =>
            Pixels (2 .. 6) := (16#46#, 16#49#, 16#49#, 16#49#, 16#31#);

         when 'A'    =>
            Pixels (2 .. 6) := (16#7E#, 16#11#, 16#11#, 16#11#, 16#7E#);

         when 'U'    =>
            Pixels (2 .. 6) := (16#3F#, 16#40#, 16#40#, 16#40#, 16#3F#);

         when 'P'    =>
            Pixels (2 .. 6) := (16#7F#, 16#09#, 16#09#, 16#09#, 16#06#);

         when 'W'    =>
            Pixels (2 .. 6) := (16#7F#, 16#20#, 16#18#, 16#20#, 16#7F#);

         when 'D'    =>
            Pixels (2 .. 6) := (16#7F#, 16#41#, 16#41#, 16#22#, 16#1C#);

         when 'E'    =>
            Pixels (2 .. 6) := (16#7F#, 16#49#, 16#49#, 16#49#, 16#41#);

         when 'V'    =>
            Pixels (2 .. 6) := (16#1F#, 16#20#, 16#40#, 16#20#, 16#1F#);

         when others =>
            null;
      end case;

      Send ("CHAR", Pixels);
   end Draw_Char;

   procedure Show_Front (Message : String) is
   begin
      -- Select page 1
      Send ("PAGE", (16#00#, 16#B1#));

      -- Start at column 0
      Send ("COLUMN", (16#00#, 16#00#, 16#10#));

      -- Clear previous distance
      for Block in 1 .. 8 loop
         Send ("CLEAR", Zero_Block);
      end loop;

      -- Restore page 1 after clearing
      Send ("PAGE", (16#00#, 16#B1#));

      -- Start at column 22
      Send ("COLUMN", (16#00#, 16#06#, 16#11#));

      -- Draw distance
      for C of Message loop
         Draw_Char (C);
      end loop;
   end Show_Front;

   procedure Show_Status (Message : String) is
   begin
      -- Select page 6
      Send ("STATUS PAGE", (16#00#, 16#B6#));

      -- Start at column 0
      Send ("COLUMN", (16#00#, 16#00#, 16#10#));

      -- Clear previous status
      for Block in 1 .. 8 loop
         Send ("CLEAR", Zero_Block);
      end loop;

      -- IMPORTANT: Select page 6 AGAIN after clearing
      Send ("STATUS PAGE", (16#00#, 16#B6#));

      -- Start at column 20
      Send ("COLUMN", (16#00#, 16#04#, 16#11#));

      -- Draw status text
      for C of Message loop
         Draw_Char (C);
      end loop;
   end Show_Status;

   -- Font: ADAptive (5x7)
   Title_Data : constant I2C_Data :=
     (16#40#,

      -- A
      16#7E#,
      16#11#,
      16#11#,
      16#11#,
      16#7E#,
      0,

      -- D
      16#7F#,
      16#41#,
      16#41#,
      16#22#,
      16#1C#,
      0,

      -- A
      16#7E#,
      16#11#,
      16#11#,
      16#11#,
      16#7E#,
      0,

      -- p
      16#7C#,
      16#14#,
      16#14#,
      16#14#,
      16#08#,
      0,

      -- t
      16#04#,
      16#3F#,
      16#44#,
      16#40#,
      16#20#,
      0,

      -- i
      16#00#,
      16#44#,
      16#7D#,
      16#40#,
      16#00#,
      0,

      -- v
      16#1C#,
      16#20#,
      16#40#,
      16#20#,
      16#1C#,
      0,

      -- e
      16#38#,
      16#54#,
      16#54#,
      16#54#,
      16#18#,
      0);

begin
   Put_Line ("ADAptive - OLED Clean Text Test");

   MicroBit.I2C.InitializeExt (MicroBit.I2C.S100kbps);

   delay 0.5;

   -- Initialize OLED
   Send ("OFF", (16#00#, 16#AE#));
   Send ("CHARGE", (16#00#, 16#8D#, 16#14#));
   Send ("ADDRESS", (16#00#, 16#20#, 16#02#));
   Send ("NORMAL", (16#00#, 16#A4#));
   Send ("NOT INVERTED", (16#00#, 16#A6#));

   -- Clear all 8 pages of display memory
   for Page in 0 .. 7 loop
      Send ("PAGE", (16#00#, UInt8 (16#B0# + Page)));

      -- Start at column 0
      Send ("COLUMN", (16#00#, 16#00#, 16#10#));

      -- 8 blocks * 16 bytes = 128 columns
      for Block in 1 .. 8 loop
         Send ("CLEAR", Zero_Block);
      end loop;
   end loop;

   Put_Line ("OLED memory cleared");

   -- Select page 3
   Send ("TEXT PAGE", (16#00#, 16#B3#));

   -- Start at column 40
   Send ("TEXT COLUMN", (16#00#, 16#08#, 16#12#));

   -- Write project name
   Send ("TEXT", Title_Data);

   -- Display on
   Send ("ON", (16#00#, 16#AF#));

   Put_Line ("ADAptive displayed");

   Put_Line ("STATUS: " & State_Text (Current_State));

   Show_Status ("STATUS: " & State_Text (Current_State));

      -- ADAptive FSM test
   -- Forward motor movement is disabled during this test.

   declare
      Max_Test_Steps : constant Natural := 60;
      Test_Steps     : Natural := 0;
   begin
      MicroBit.MotorDriver.Drive (Direction => MicroBit.MotorDriver.Stop);

      MicroBit.MotorDriver.Servo (ServoPin => 2, Angle => 84);

      Current_State := Stop;

      Put_Line ("ADAptive - FSM TEST START");

      loop
         exit when Test_Steps >= Max_Test_Steps;
         Test_Steps := Test_Steps + 1;

         Put_Line ("FSM STATE: " & State_Text (Current_State));

         case Current_State is

            when Stop          =>
               MicroBit.MotorDriver.Drive
                 (Direction => MicroBit.MotorDriver.Stop);

               Show_Status ("STATUS: STOP");

               delay 0.5;
               Current_State := Scan;

            when Scan          =>
               MicroBit.MotorDriver.Drive
                 (Direction => MicroBit.MotorDriver.Stop);

               Show_Status ("STATUS: SCAN");

               -- RIGHT: 64 degrees
               MicroBit.MotorDriver.Servo (ServoPin => 2, Angle => 64);
               delay 0.8;

               Reading_1 := Front_Sensor.Read;
               delay 0.07;
               Reading_2 := Front_Sensor.Read;
               delay 0.07;
               Reading_3 := Front_Sensor.Read;

               Distance_A := Median (Reading_1, Reading_2, Reading_3);

               Put_Line
                 ("RIGHT RAW:"
                  & Distance_cm'Image (Reading_1)
                  & ","
                  & Distance_cm'Image (Reading_2)
                  & ","
                  & Distance_cm'Image (Reading_3));

               Put_Line ("RIGHT:" & Distance_cm'Image (Distance_A));

               -- FRONT: 84 degrees
               MicroBit.MotorDriver.Servo (ServoPin => 2, Angle => 84);
               delay 0.8;

               Reading_1 := Front_Sensor.Read;
               delay 0.07;
               Reading_2 := Front_Sensor.Read;
               delay 0.07;
               Reading_3 := Front_Sensor.Read;

               Distance_Front := Median (Reading_1, Reading_2, Reading_3);
               Put_Line
                 ("FRONT RAW:"
                  & Distance_cm'Image (Reading_1)
                  & ","
                  & Distance_cm'Image (Reading_2)
                  & ","
                  & Distance_cm'Image (Reading_3));

               Put_Line ("FRONT:" & Distance_cm'Image (Distance_Front));

               -- LEFT: 104 degrees
               MicroBit.MotorDriver.Servo (ServoPin => 2, Angle => 104);
               delay 0.8;

               Reading_1 := Front_Sensor.Read;
               delay 0.07;
               Reading_2 := Front_Sensor.Read;
               delay 0.07;
               Reading_3 := Front_Sensor.Read;

               Distance_B := Median (Reading_1, Reading_2, Reading_3);
               Put_Line
                 ("LEFT RAW:"
                  & Distance_cm'Image (Reading_1)
                  & ","
                  & Distance_cm'Image (Reading_2)
                  & ","
                  & Distance_cm'Image (Reading_3));

               Put_Line ("LEFT:" & Distance_cm'Image (Distance_B));

               MicroBit.MotorDriver.Servo (ServoPin => 2, Angle => 84);
               delay 0.8;

               -- Prefer straight when the front is clear.
               -- Turn only when the front is blocked.
               Best_Direction := Blocked;

               if Distance_Front >= 45 and then Distance_Front <= 200 then
                  Best_Direction := Straight;

               elsif Distance_A >= 45 and then Distance_A <= 200 then
                  Best_Direction := Side_A;

               elsif Distance_B >= 45 and then Distance_B <= 200 then
                  Best_Direction := Side_B;
               end if;

                              case Best_Direction is
                  when Straight =>
                     Show_Direction ('F');
                     Put_Line ("FSM CHOICE: FRONT");
                     Current_State := Verify;

                  when Side_A =>
                     Show_Direction ('R');
                     Put_Line ("FSM CHOICE: RIGHT");
                     Current_State := Turn;

                  when Side_B =>
                     Show_Direction ('L');
                     Put_Line ("FSM CHOICE: LEFT");
                     Current_State := Turn;

                  when Blocked =>
                     Show_Direction ('S');
                     Put_Line ("FSM CHOICE: BLOCKED");
                     Current_State := Stop;
               end case;

            when Turn          =>
               Show_Status ("STATUS: TURN");

               case Best_Direction is
                  when Side_A =>
                     Put_Line ("FSM TURN: RIGHT");

                     MicroBit.MotorDriver.Drive
                       (Direction => MicroBit.MotorDriver.Rotating_Right,
                        Speed     =>
                          (rf => 800, rb => 800, lf => 800, lb => 800));

                     delay 0.3;

                  when Side_B =>
                     Put_Line ("FSM TURN: LEFT");

                     MicroBit.MotorDriver.Drive
                       (Direction => MicroBit.MotorDriver.Rotating_Left,
                        Speed     =>
                          (rf => 800, rb => 800, lf => 800, lb => 800));

                     delay 0.3;

                  when others =>
                     null;
               end case;

               MicroBit.MotorDriver.Drive
                 (Direction => MicroBit.MotorDriver.Stop);

               Current_State := Verify;

            when Verify        =>
               MicroBit.MotorDriver.Drive
                 (Direction => MicroBit.MotorDriver.Stop);

               Show_Status ("STATUS: VERIFY");

               MicroBit.MotorDriver.Servo (ServoPin => 2, Angle => 84);
               delay 0.8;

               Reading_1 := Front_Sensor.Read;
               delay 0.07;
               Reading_2 := Front_Sensor.Read;
               delay 0.07;
               Reading_3 := Front_Sensor.Read;

               Front_Distance := Median (Reading_1, Reading_2, Reading_3);

               Put_Line
                 ("VERIFY RAW:"
                  & Distance_cm'Image (Reading_1)
                  & ","
                  & Distance_cm'Image (Reading_2)
                  & ","
                  & Distance_cm'Image (Reading_3));

               Put_Line ("VERIFY FRONT:" & Distance_cm'Image (Front_Distance));

               if Front_Distance >= 45 and then Front_Distance <= 400 then
                  Put_Line ("VERIFY RESULT: CLEAR");
                  Current_State := Forward;
               else
                  Put_Line ("VERIFY RESULT: BLOCKED");
                  Current_State := Stop;
               end if;

            when Forward       =>
               Put_Line ("FSM MOTOR: FORWARD PULSE");

               MicroBit.MotorDriver.Servo (ServoPin => 2, Angle => 84);

               MicroBit.MotorDriver.Drive
                 (Direction => MicroBit.MotorDriver.Forward,
                  Speed     => (rf => 800, rb => 800, lf => 800, lb => 800));

               delay 0.2;

               MicroBit.MotorDriver.Drive
                 (Direction => MicroBit.MotorDriver.Stop);

               Put_Line ("FSM MOTOR: STOP");

               -- Recheck distance before the next movement
               Current_State := Verify;

            when Reverse_Drive =>
               -- Reserved for a future reverse maneuver
               MicroBit.MotorDriver.Drive
                 (Direction => MicroBit.MotorDriver.Stop);
               Current_State := Stop;

         end case;
      end loop;

      MicroBit.MotorDriver.Drive (Direction => MicroBit.MotorDriver.Stop);

      Show_Status ("STATUS: STOP");
      Put_Line ("ADAptive - FSM TEST COMPLETE");

      -- Stay stopped until reset
      loop
         delay 1.0;
      end loop;
   end;

end Main;

