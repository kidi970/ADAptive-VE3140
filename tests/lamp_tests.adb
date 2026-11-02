with Ada.Text_IO; use Ada.Text_IO;
with Adaptive_Lamp_Policy; use Adaptive_Lamp_Policy;
with Adaptive_Lamp_Control;
procedure Lamp_Tests is
   Checks : Natural := 0;
   Enabled, Failed : Boolean;
   Mode : Lamp_Mode;
   P : Lamp_Outputs;
   type Phases_Array is array (Positive range <>) of Natural;
   Phases : constant Phases_Array := (0, 499, 500, 999, 1_000);
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if not Condition then raise Program_Error with Name; end if;
      Checks := Checks + 1;
   end Check;
begin
   for M in Lamp_Mode loop
      for Phase of Phases loop
         P := Outputs (M, Phase);
         Check (P.Brake = (M in Parked | Braking | Faulted), "brake intent");
         Check (P.Left = ((M in Turning_Left | Faulted) and Phase mod 1_000 < 500),
                "left blink boundary");
         Check (P.Right = ((M in Turning_Right | Faulted) and Phase mod 1_000 < 500),
                "right blink boundary");
      end loop;
   end loop;
   Adaptive_Lamp_Control.State.Read (Enabled, Mode, Failed);
   Check (not Enabled and not Failed and Mode = Parked, "disabled before initialize");
   Adaptive_Lamp_Control.State.Enable;
   Adaptive_Lamp_Control.State.Set_Mode (Turning_Left);
   Adaptive_Lamp_Control.State.Read (Enabled, Mode, Failed);
   Check (Enabled and Mode = Turning_Left, "publish turn intent");
   Adaptive_Lamp_Control.State.Latch_Fault;
   declare
      task type Publisher;
      task body Publisher is
      begin
         for I in 1 .. 100 loop
            Adaptive_Lamp_Control.State.Set_Mode (Moving);
         end loop;
      end Publisher;
      A, B : Publisher;
   begin
      null;
   end;
   Adaptive_Lamp_Control.State.Read (Enabled, Mode, Failed);
   Check (Mode = Faulted, "concurrent publishers cannot clear fault");
   Adaptive_Lamp_Control.State.Task_Failed;
   Adaptive_Lamp_Control.State.Enable;
   Adaptive_Lamp_Control.State.Read (Enabled, Mode, Failed);
   Check (Failed and Mode = Faulted, "worker failure is sticky");
   Put_Line ("PASS" & Natural'Image (Checks) & " lamp checks");
end Lamp_Tests;
