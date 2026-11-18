with Ada.Real_Time; use Ada.Real_Time;
with System;
with MicroBit; use MicroBit;
with nRF.GPIO; use nRF.GPIO;
with Adaptive_Lamp_Policy; use Adaptive_Lamp_Policy;
with Adaptive_Lamp_Control;
with Adaptive_Safety;
with Adaptive_Policy;
with Adaptive_Proximity;
with Adaptive_Alert_Policy;
with Adaptive_Audio;
package body Adaptive_Lights is
   Period : constant Time_Span := Milliseconds (50);

   procedure Initialize is
   begin
      Adaptive_Lamp_Control.State.Enable;
   end Initialize;

   function Failed return Boolean is
      Enabled, Failure : Boolean;
      Mode : Lamp_Mode;
   begin
      Adaptive_Lamp_Control.State.Read (Enabled, Mode, Failure);
      return Failure;
   end Failed;

   task Lamp_Task with Priority => System.Priority'First, Storage_Size => 2_048;

   task body Lamp_Task is
      Next_Release, Epoch, Now : Time;
      Enabled, Failure, Configured : Boolean := False;
      Mode : Lamp_Mode;
      Previous_Mode : Lamp_Mode := Parked;
      Pattern : Lamp_Outputs;
      Phase, Audio_Phase : Natural := 0;
      Front : Adaptive_Policy.Distance;
      Fresh : Boolean;
      procedure Configure (Pin : in out GPIO_Point) is
      begin
         if Powerbank_LED_Test then Pin.Set; else Pin.Clear; end if;
         Pin.Configure_IO
           ((Mode => Mode_Out, Resistors => No_Pull,
             Input_Buffer => Input_Buffer_Disconnect,
             Sense => Sense_Disabled, Drive => Drive_H0H1));
      end Configure;
      procedure Write (Pin : in out GPIO_Point; Value : Boolean) is
      begin
         if Value then Pin.Set; else Pin.Clear; end if;
      end Write;
   begin
      Next_Release := Clock;
      Epoch := Next_Release;
      loop
         delay until Next_Release;
         Adaptive_Lamp_Control.State.Read (Enabled, Mode, Failure);
         if Adaptive_Safety.Stop_Requested and then Mode /= Faulted then
            Mode := Braking;
         end if;
         if Enabled then
            if not Configured then
               Configure (MB_P0); Configure (MB_P12); Configure (MB_P16);
               Configured := True;
            end if;
            Now := Clock;
            if Mode /= Previous_Mode then
               Epoch := Now;
               Previous_Mode := Mode;
            end if;
            if Now - Epoch >= Milliseconds (1_000) then Epoch := Now; end if;
            Phase := Natural (To_Duration (Now - Epoch) * 1_000.0);
            Pattern := (if Powerbank_LED_Test then (True, True, True)
                        else Outputs (Mode, Phase));
            Write (MB_P0, Pattern.Brake);
            Write (MB_P12, Pattern.Left);
            Write (MB_P16, Pattern.Right);
            Adaptive_Proximity.State.Read (Front, Fresh);
            Adaptive_Audio.Set_Tone (Adaptive_Alert_Policy.Beep
              (Front, Audio_Phase, Fresh, Adaptive_Safety.Start_Requested,
               Adaptive_Safety.Stop_Requested));
            Audio_Phase := (Audio_Phase + 50) mod 1_000;
         end if;
         Next_Release := Next_Release + Period;
         -- Skip missed releases; never monopolize CPU to catch up with LEDs.
         if Next_Release <= Clock then Next_Release := Clock + Period; end if;
      end loop;
   exception
      when others =>
         -- A task exception cannot propagate into Main. Publish the failure
         -- before parking this worker; Main performs the bounded motor stop.
         Adaptive_Lamp_Control.State.Task_Failed;
         Adaptive_Safety.Request_Stop;
         begin Adaptive_Audio.Set_Tone (False); exception when others => null; end;
         loop delay 1.0; end loop;
   end Lamp_Task;
end Adaptive_Lights;
