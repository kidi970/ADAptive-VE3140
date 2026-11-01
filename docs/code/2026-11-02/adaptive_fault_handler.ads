with Ada.Exceptions;
with Adaptive_Errors;
generic
   with procedure Latch_Stop;
   with procedure Stop_Motors;
   with procedure Log (Message : String);
package Adaptive_Fault_Handler is
   type Stop_Result is (Not_Attempted, Acknowledged, Failed);
   type Fault_Status is record
      Latched : Boolean := False;
      Primary : Adaptive_Errors.Fault_Code := Adaptive_Errors.No_Fault;
      Stop_Command : Stop_Result := Not_Attempted;
      Stop_Fault : Adaptive_Errors.Fault_Code := Adaptive_Errors.No_Fault;
      Logging_Failed : Boolean := False;
   end record;

   -- Called only by the sequential supervisor, never from an interrupt.
   -- Latch_Stop must be a non-raising, nonblocking assignment to the stop flag.
   -- Stop_Motors must use the bounded I2C driver. There is no reset operation.
   procedure Handle (Occurrence : Ada.Exceptions.Exception_Occurrence);
   function Status return Fault_Status;
   -- Acknowledged means the controller accepted the stop write, not that
   -- wheel motion was physically measured. Failed requires power isolation.
end Adaptive_Fault_Handler;
