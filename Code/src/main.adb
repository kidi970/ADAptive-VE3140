with MicroBit;         use MicroBit;
with MicroBit.Ultrasonic;
with MicroBit.Types;   use MicroBit.Types;
with MicroBit.Console; use MicroBit.Console;
with MicroBit.I2C;
with HAL;              use HAL;
with HAL.I2C;          use HAL.I2C;

procedure Main is
   package Front_Sensor is new MicroBit.Ultrasonic (MB_P13, MB_P1);

   Front_Distance : Distance_cm := 0;
   Status : I2C_Status;

   Port : constant Any_I2C_Port := MicroBit.I2C.ControllerExt;

   procedure Send (Name : String; Data : I2C_Data) is
   begin
      Port.Master_Transmit (Addr => 16#78#, Data => Data, Status => Status);

      if Status /= Ok then
         Put_Line (Name & ": " & I2C_Status'Image (Status));
      end if;
   end Send;

   Zero_Block : constant I2C_Data (1 .. 17) := (1 => 16#40#, others => 16#00#);



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

         when others =>
            null;
      end case;

      Send ("CHAR", Pixels);
   end Draw_Char;

   procedure Show_Front (Message : String) is
   begin
      -- Select OLED page 5 and column 0
      Send ("PAGE", (16#00#, 16#B5#));
      Send ("COLUMN", (16#00#, 16#00#, 16#10#));

      -- Clear 128 columns
      for Block in 1 .. 8 loop
         Send ("CLEAR", Zero_Block);
      end loop;

      -- Start writing at column 22
      Send ("COLUMN", (16#00#, 16#06#, 16#11#));

      for C of Message loop
         Draw_Char (C);
      end loop;
   end Show_Front;

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


   loop
      Front_Distance := Front_Sensor.Read;

      if Front_Distance >= 2 and then Front_Distance <= 400 then
         Put_Line ("FRONT:" & Distance_cm'Image (Front_Distance) & " cm");

         Show_Front ("FRONT:" & Distance_cm'Image (Front_Distance) & " CM   ");
      else
         Put_Line ("FRONT: INVALID");
         Show_Front ("FRONT: --- CM   ");
      end if;

      delay 0.5;
   end loop;
end Main;

