with MicroBit.I2C;
with HAL; use HAL;
with HAL.I2C; use HAL.I2C;
with Adaptive_Lamp_Control;
with Adaptive_Lamp_Policy; use Adaptive_Lamp_Policy;
with Adaptive_Safety;
package body Adaptive_Motion is
   Port : constant Any_I2C_Port := MicroBit.I2C.ControllerExt;
   procedure Write (Data : I2C_Data) is
      Status : I2C_Status;
   begin
      Port.Master_Transmit (16#80#, Data, Status, Timeout => 20);
      if Status /= Ok then
         raise Program_Error with "Motor I2C " & I2C_Status'Image (Status);
      end if;
   end Write;
   procedure Stop is
   begin
      Adaptive_Lamp_Control.State.Set_Mode (Braking);
      Write ((0 => 16#06#, 1 .. 32 => 0));
      Adaptive_Safety.Motion_Commanded := False;
   end Stop;
   procedure Initialize is
   begin
      MicroBit.I2C.InitializeExt (MicroBit.I2C.S100kbps);
      Write ((16#00#, 16#20#));
      Stop;
      Write ((16#00#, 16#10#));
      Write ((16#FE#, 121));
      Write ((16#00#, 16#20#));
      delay 0.001;
      Aim (Center);
   end Initialize;
   procedure Drive (Direction : Choice) is
      Buffer : I2C_Data (0 .. 32) := (0 => 16#06#, others => 0);
      -- User observed on 2026-11-04: the old F polarity moves this car
      -- backwards. Invert each motor pair; retain M4,M3,M2,M1 ordering
      -- (left front, left rear, right front, right rear, per wheel test).
      F : constant I2C_Data := (1 .. 6 => 0, 7 => 16#20#, 8 => 3);
      B : constant I2C_Data := (1 .. 2 => 0, 3 => 16#20#, 4 => 3, 5 .. 8 => 0);
   begin
      if Direction = Blocked then Stop; return; end if;
      if Adaptive_Safety.Stop_Requested
        or else not Adaptive_Safety.Start_Requested
      then raise Program_Error with "Motion inhibited"; end if;
      case Direction is
         when Straight =>
            Buffer (1 .. 8) := F; Buffer (9 .. 16) := F;
            Buffer (17 .. 24) := F; Buffer (25 .. 32) := F;
         when Right =>
            Buffer (1 .. 8) := F; Buffer (9 .. 16) := F;
            Buffer (17 .. 24) := B; Buffer (25 .. 32) := B;
         when Left =>
            Buffer (1 .. 8) := B; Buffer (9 .. 16) := B;
            Buffer (17 .. 24) := F; Buffer (25 .. 32) := F;
         when Blocked => null;
      end case;
      Write (Buffer);
      Adaptive_Safety.Motion_Commanded := True;
      if Adaptive_Safety.Stop_Requested then
         Stop;
         raise Program_Error with "Stop during motor write";
      end if;
      Adaptive_Lamp_Control.State.Set_Mode
        ((case Direction is
            when Straight => Moving,
            when Left => Turning_Left,
            when Right => Turning_Right,
            when Blocked => Braking));
   end Drive;
   procedure Aim (Angle : Natural) is
      Counts : UInt16;
   begin
      if Angle not in 34 .. 134
        or else (not Outer_Angles_Verified and then Angle not in 54 .. 114)
      then raise Constraint_Error with "Unverified servo angle"; end if;
      -- S2 is PCA9685 channel 14: 600..2400 us over 0..180 degrees.
      Counts := UInt16 (Float'Rounding
        ((600.0 + Float (Angle) * 10.0) * 4096.0 / 20000.0));
      Write ((16#3E#, 0, 0, UInt8 (Counts and 16#FF#),
              UInt8 (Shift_Right (Counts, 8))));
   end Aim;
end Adaptive_Motion;
