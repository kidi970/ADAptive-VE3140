with MicroBit.I2C;
with HAL; use HAL;
with HAL.I2C; use HAL.I2C;
with Adaptive_Safety;
with Adaptive_Errors;
with Adaptive_Lamp_Control;
with Adaptive_Lamp_Policy;
package body Adaptive_Motion is
   Port : constant Any_I2C_Port := MicroBit.I2C.ControllerExt;
   Ready : Boolean := False;
   Burst_Enabled : Boolean := False;
   procedure Write (Data : I2C_Data) is
      Status : I2C_Status;
   begin
      if not MicroBit.I2C.InitializedExt then
         raise Adaptive_Errors.Motor_Not_Ready with "External I2C not initialized";
      end if;
      Port.Master_Transmit (16#80#, Data, Status, Timeout => 20);
      if Status /= Ok then
         Ready := False;
         Burst_Enabled := False;
         Adaptive_Safety.Motor_Stop_Acknowledged := False;
         Adaptive_Safety.Request_Stop;
         raise Adaptive_Errors.Motor_Bus_Error
           with "addr8=128 reg=" & UInt8'Image (Data (Data'First))
             & " status=" & I2C_Status'Image (Status);
      end if;
      if Data'Length = 2 and then Data (Data'First) = 16#00# then
         Burst_Enabled := (Data (Data'Last) and 16#20#) /= 0;
      end if;
   end Write;
   procedure Stop is
   begin
      Adaptive_Lamp_Control.State.Set_Mode (Adaptive_Lamp_Policy.Braking);
      Adaptive_Safety.Motor_Stop_Acknowledged := False;
      -- If auto-increment is unknown, address each motor PWM channel's
      -- FULL_OFF bit independently. Recovery must never wake the oscillator.
      if Burst_Enabled then
         declare
            Buffer : I2C_Data (0 .. 32) := (0 => 16#06#, others => 0);
         begin
            for Channel in 0 .. 7 loop
               Buffer (4 + 4 * Channel) := 16#10#; -- explicit FULL_OFF
            end loop;
            Write (Buffer);
         end;
      else
         for Channel in 0 .. 7 loop
            Write ((UInt8 (16#09# + 4 * Channel), 16#10#));
         end loop;
      end if;
      Adaptive_Safety.Motion_Commanded := False;
      Adaptive_Safety.Motor_Stop_Acknowledged := True;
   end Stop;
   procedure Initialize is
   begin
      Ready := False;
      Burst_Enabled := False;
      Adaptive_Safety.Motor_Stop_Acknowledged := False;
      if Adaptive_Safety.Stop_Requested then
         raise Adaptive_Errors.Stop_Latched_Error with "Startup inhibited";
      end if;
      if not MicroBit.I2C.InitializedExt then
         MicroBit.I2C.InitializeExt (MicroBit.I2C.S100kbps);
      end if;
      -- Clear all motor outputs before waking an already powered PCA9685.
      Stop;
      Write ((16#00#, 16#10#));
      Write ((16#FE#, 121));
      Write ((16#00#, 16#20#));
      delay 0.001;
      Aim (Center);
      Ready := True;
   end Initialize;
   procedure Drive (Direction : Choice) is
      Buffer : I2C_Data (0 .. 32) := (0 => 16#06#, others => 0);
      PWM_Count : constant UInt16 := 800;
      -- Encode the two fixed channel patterns directly. Importing the legacy
      -- DFR0548 helper also elaborates MicroBit.Console before Main, even
      -- though none of that driver's bus operations is used here.
      F : constant I2C_Data (1 .. 8) :=
        (3 => UInt8 (PWM_Count and 16#FF#),
         4 => UInt8 (Shift_Right (PWM_Count, 8)), others => 0);
      B : constant I2C_Data (1 .. 8) :=
        (7 => UInt8 (PWM_Count and 16#FF#),
         8 => UInt8 (Shift_Right (PWM_Count, 8)), others => 0);
   begin
      if Direction = Blocked then Stop; return; end if;
      if Adaptive_Safety.Stop_Requested then
         raise Adaptive_Errors.Stop_Latched_Error with "Drive inhibited";
      elsif not Ready then
         raise Adaptive_Errors.Motor_Not_Ready with "Motor setup incomplete";
      elsif not Adaptive_Safety.Start_Requested then
         raise Adaptive_Errors.Motor_Not_Ready with "Press button A to arm";
      end if;
      case Direction is
         when Straight =>
            Buffer (1 .. 8) := F; Buffer (9 .. 16) := F;
            Buffer (17 .. 24) := F; Buffer (25 .. 32) := F;
         when Right =>
            Buffer (1 .. 8) := B; Buffer (9 .. 16) := B;
            Buffer (17 .. 24) := F; Buffer (25 .. 32) := F;
         when Left =>
            Buffer (1 .. 8) := F; Buffer (9 .. 16) := F;
            Buffer (17 .. 24) := B; Buffer (25 .. 32) := B;
         when Blocked => null;
      end case;
      Adaptive_Safety.Motor_Stop_Acknowledged := False;
      Write (Buffer);
      Adaptive_Safety.Motion_Commanded := Direction /= Blocked;
      -- A button interrupt can arrive during the bounded bus transaction.
      if Adaptive_Safety.Stop_Requested then
         Stop;
         raise Adaptive_Errors.Stop_Latched_Error with "Stop during drive write";
      end if;
      Adaptive_Lamp_Control.State.Set_Mode
        ((case Direction is
             when Straight => Adaptive_Lamp_Policy.Moving,
             when Left => Adaptive_Lamp_Policy.Turning_Left,
             when Right => Adaptive_Lamp_Policy.Turning_Right,
             when Blocked => Adaptive_Lamp_Policy.Braking));
   end Drive;
   procedure Aim (Angle : Natural) is
      Counts : UInt16;
   begin
      if Angle not in 34 .. 134
        or else (not Outer_Angles_Verified and then Angle not in 54 .. 114)
      then raise Adaptive_Errors.Servo_Limit_Error
        with "Unverified servo angle"; end if;
      if Adaptive_Safety.Stop_Requested then
         raise Adaptive_Errors.Stop_Latched_Error with "Servo inhibited";
      end if;
      -- S2 is PCA9685 channel 14: 600..2400 us over 0..180 degrees.
      Counts := UInt16 (Float'Rounding
        ((600.0 + Float (Angle) * 10.0) * 4096.0 / 20000.0));
      Write ((16#3E#, 0, 0, UInt8 (Counts and 16#FF#),
              UInt8 (Shift_Right (Counts, 8))));
   end Aim;
end Adaptive_Motion;
