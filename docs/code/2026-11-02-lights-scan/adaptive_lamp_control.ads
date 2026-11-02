with System;
with Adaptive_Lamp_Policy; use Adaptive_Lamp_Policy;
package Adaptive_Lamp_Control is
   -- No GPIO or I2C in this protected object. Motor/supervisor publish intent;
   -- only the lamp task owns the three outputs. Calls are safe from stop ISR.
   protected State is
      pragma Interrupt_Priority (System.Interrupt_Priority'Last);
      procedure Enable;
      procedure Set_Mode (Mode : Lamp_Mode);
      procedure Latch_Fault;
      procedure Task_Failed;
      procedure Read (Enabled : out Boolean; Mode : out Lamp_Mode;
                      Failed : out Boolean);
   private
      Active : Boolean := False;
      Current : Lamp_Mode := Parked;
      Worker_Failed : Boolean := False;
   end State;
end Adaptive_Lamp_Control;
