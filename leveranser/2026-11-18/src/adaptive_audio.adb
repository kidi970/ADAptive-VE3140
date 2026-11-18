with HAL; use HAL;
with System.Storage_Elements;
with MicroBit; use MicroBit;
with nRF.GPIO; use nRF.GPIO;
with NRF_SVD.PWM; use NRF_SVD.PWM;
package body Adaptive_Audio is
   -- EasyDMA requires a persistent, word-aligned sample in RAM.
   Sample : aliased UInt16 := 64 with Alignment => 4;
   Configured, Playing : Boolean := False;
   -- The bundled SVD models CNT as an enum containing only Disabled=4.
   -- Nordic specifies an unsigned 15-bit halfword count; use a typed overlay.
   Count : UInt32 with Import, Address => PWM0_Periph.SEQ (0).CNT'Address,
     Volatile_Full_Access;
   procedure Set_Tone (Enabled : Boolean) is
   begin
      if not Configured then
         MB_SPKR.Clear;
         MB_SPKR.Configure_IO
           ((Mode => Mode_Out, Resistors => No_Pull,
             Input_Buffer => Input_Buffer_Disconnect,
             Sense => Sense_Disabled, Drive => Drive_S0S1));
         PWM0_Periph.ENABLE.ENABLE := Disabled;
         PWM0_Periph.SHORTS := (others => <>);
         PWM0_Periph.INTEN := (others => <>);
         PWM0_Periph.MODE.UPDOWN := Up;
         PWM0_Periph.PRESCALER.PRESCALER := Div_16;
         PWM0_Periph.COUNTERTOP.COUNTERTOP := 500; -- 2 kHz
         PWM0_Periph.DECODER := (LOAD => Common, MODE => Refreshcount, others => <>);
         PWM0_Periph.LOOP_k := (others => <>);
         PWM0_Periph.SEQ (0).PTR := UInt32
           (System.Storage_Elements.To_Integer (Sample'Address));
         Count := 1;
         PWM0_Periph.SEQ (0).REFRESH.CNT := Continuous;
         PWM0_Periph.SEQ (0).ENDDELAY.CNT := 0;
         PWM0_Periph.PSEL.OUT_k (0) :=
           (PIN => 0, CONNECT => Connected, others => 0);
         for I in 1 .. 3 loop
            PWM0_Periph.PSEL.OUT_k (I) :=
              (PIN => 0, CONNECT => Disconnected, others => 0);
         end loop;
         Configured := True;
      end if;
      if Enabled and then not Playing then
         PWM0_Periph.ENABLE.ENABLE := NRF_SVD.PWM.Enabled;
         PWM0_Periph.TASKS_SEQSTART (0) := 1;
      elsif not Enabled and then Playing then
         PWM0_Periph.TASKS_STOP := 1;
         -- STOP completes at the end of this 0.5 ms PWM period.
         -- Leave the peripheral enabled; do not disable before STOPPED.
         MB_SPKR.Clear;
      end if;
      Playing := Enabled;
   end Set_Tone;
end Adaptive_Audio;
