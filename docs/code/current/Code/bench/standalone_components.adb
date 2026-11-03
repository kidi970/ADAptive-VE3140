with Ada.Real_Time; use Ada.Real_Time;
with Ada.Exceptions;
with MicroBit; use MicroBit;
with Adaptive_Log; use Adaptive_Log;
with MicroBit.I2C;
with nRF.GPIO;
with HAL; use HAL;
with HAL.I2C; use HAL.I2C;
with Adaptive_Echo;
with Adaptive_Range_Model; use Adaptive_Range_Model;
with Adaptive_Bench_Model;
with Adaptive_OLED_Codec;
with Adaptive_Bench_OLED;
procedure Standalone_Components is
   package Model renames Adaptive_Bench_Model;
   package Front is new Adaptive_Echo (MB_P13, MB_P1);
   package Left is new Adaptive_Echo (MB_P14, MB_P2);
   package Right is new Adaptive_Echo (MB_P15, MB_P8);
   type Points is array (Positive range <>) of nRF.GPIO.GPIO_Point;
   -- Legacy, detached bench wiring only: left P0, right P9, clear P16,
   -- stop P3. This is NOT the car profile (brake P0, left P12, right P16).
   -- Keep this fixture explicit; no physical rewiring is assumed or requested.
   Lights : Points := (MB_P0, MB_P9, MB_P16, MB_P3);
   Rows : Points := (MB_P21, MB_P22, MB_P23, MB_P24, MB_P25);
   Output : constant nRF.GPIO.GPIO_Configuration :=
     (Mode => nRF.GPIO.Mode_Out, Resistors => nRF.GPIO.No_Pull,
      Input_Buffer => nRF.GPIO.Input_Buffer_Connect,
      Sense => nRF.GPIO.Sense_Disabled, Drive => nRF.GPIO.Drive_S0S1);
   function OLED_Write (Address_7bit : Positive;
                        Data : Adaptive_OLED_Codec.Bytes) return Boolean is
      Buffer : I2C_Data (Data'Range);
      Status : I2C_Status;
   begin
      if Address_7bit not in 16#3C# .. 16#3D# then
         raise Constraint_Error with "OLED address allowlist";
      end if;
      for I in Data'Range loop Buffer (I) := UInt8 (Data (I)); end loop;
      -- HAL expects the shifted address: 0x3C -> 0x78, 0x3D -> 0x7A.
      MicroBit.I2C.ControllerExt.Master_Transmit
        (UInt10 (Address_7bit * 2), Buffer, Status, Timeout => 25);
      if Status /= Ok then Put_Line ("OLED_IO," & I2C_Status'Image (Status)); end if;
      return Status = Ok;
   end OLED_Write;
   procedure Initialize_OLED_Bus is
   begin
      MicroBit.I2C.InitializeExt (MicroBit.I2C.S100kbps);
   end Initialize_OLED_Bus;
   package Screen is new Adaptive_Bench_OLED (OLED_Write, Initialize_OLED_Bus);
   Next_Trigger : Time := Time_First;
   Epoch : Time;
   F, L, R : Model.Statistics;
   State : Model.Indication;
   OK : Boolean;
   Sequence : Natural := 0;
   function Read_Window (Sensor : Character) return Model.Statistics is
      Values : Model.Readings;
      Started : Time;
   begin
      for I in Values'Range loop
         delay until Next_Trigger;
         Started := Clock;
         Next_Trigger := Started + Milliseconds (65);
         case Sensor is
            when 'F' => Values (I) := Front.Read;
            when 'L' => Values (I) := Left.Read;
            when 'R' => Values (I) := Right.Read;
            when others => raise Constraint_Error;
         end case;
         Sequence := Sequence + 1;
         Put_Line ("RAW," & Natural'Image (Sequence) & "," & Sensor & ","
           & Echo_Status'Image (Values (I).Status) & ","
           & Natural'Image (Values (I).Pulse_Us) & ","
           & Natural'Image (Values (I).Elapsed_Us) & ","
           & Natural'Image (Natural (Values (I).Distance_CM * 1000.0)) & ","
           & Natural'Image (Natural (To_Duration (Started - Epoch) * 1_000_000.0)));
      end loop;
      return Model.Summarize (Values);
   end Read_Window;
   procedure Indicate is
   begin
      for Light of Lights loop Light.Clear; end loop;
      case State is
         when Model.Unknown | Model.Stop => Lights (4).Set;
         when Model.Caution => Lights (1).Set; Lights (2).Set;
         when Model.Clear => Lights (3).Set;
      end case;
   end Indicate;
   function Distance_Text (S : Model.Statistics) return String is
   begin
      if S.Valid_Count /= 3 then return "UNKNOWN";
      elsif not S.Stable then return "UNSTABLE";
      else return Natural'Image (Natural (Float'Floor (S.Minimum))) & " CM";
      end if;
   end Distance_Text;
begin
   Put_Line ("ADAptive COMPONENT BENCH v1; NO_MOTOR_WRITES; MATRIX_DISABLED");
   -- P3 shares an LED-matrix column. Keep every matrix row LOW and do not
   -- link DisplayRT. The built-in matrix is intentionally disabled here.
   for Row of Rows loop Row.Clear; Row.Configure_IO (Output); end loop;
   for Light of Lights loop Light.Clear; Light.Configure_IO (Output); end loop;
   for I in Lights'Range loop
      Put_Line ("LED_CHASE," & Positive'Image (I));
      Lights (I).Set; delay 0.15; Lights (I).Clear;
   end loop;
   begin
      OK := Screen.Initialize;
   exception
      when E : others =>
         -- A failed optional OLED bus must not prevent raw sensor diagnosis.
         OK := False;
         Put_Line ("OLED_INIT_FAULT," & Ada.Exceptions.Exception_Name (E));
   end;
   Put_Line ("OLED_READY," & Boolean'Image (OK) & ",ADDRESS_7BIT="
             & Natural'Image (Screen.Address));
   if OK then OK := Screen.Show_Line (0, "ADAPTIVE BENCH"); end if;
   Epoch := Clock;
   for Frame in 1 .. 15 loop
      -- Remove the previous frame's CLEAR indication before acquiring data.
      State := Model.Unknown; Indicate;
      F := Read_Window ('F'); L := Read_Window ('L'); R := Read_Window ('R');
      State := Model.Assess (F, L, R); Indicate;
      if Screen.Ready then
         OK := Screen.Show_Line (2, "FRONT " & Distance_Text (F))
           and then Screen.Show_Line (3, "LEFT " & Distance_Text (L))
           and then Screen.Show_Line (4, "RIGHT " & Distance_Text (R))
           and then Screen.Show_Line (6, Model.Indication'Image (State));
      end if;
      Put_Line ("FRAME," & Positive'Image (Frame) & ","
        & Model.Indication'Image (State) & ",OLED=" & Boolean'Image (Screen.Ready)
        & ",F=" & Distance_Text (F) & ",L=" & Distance_Text (L)
        & ",R=" & Distance_Text (R));
   end loop;
   State := Model.Unknown; Indicate;
   if Screen.Ready then OK := Screen.Show_Line (6, "TEST DONE"); end if;
   Put_Line ("DONE,COMPONENT_BENCH,15,135");
   loop delay 1.0; end loop;
exception
   when E : others =>
      for Light of Lights loop Light.Clear; end loop;
      Lights (4).Set;
      Put_Line ("BENCH_FAULT," & Ada.Exceptions.Exception_Name (E));
      loop delay 1.0; end loop;
end Standalone_Components;
