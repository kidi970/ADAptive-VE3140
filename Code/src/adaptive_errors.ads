with Ada.Exceptions;
package Adaptive_Errors is
   Motor_Bus_Error     : exception;
   Motor_Not_Ready     : exception;
   Servo_Limit_Error   : exception;
   Stop_Latched_Error  : exception;
   Safety_Setup_Error  : exception;

   type Fault_Code is
     (No_Fault, Motor_Bus_Fault, Initialization_Fault, Servo_Range_Fault,
      Stop_Latch_Fault, Safety_Setup_Fault, Constraint_Fault, Program_Fault,
      Storage_Fault, Unexpected_Fault);

   function Classify (Id : Ada.Exceptions.Exception_Id) return Fault_Code;
end Adaptive_Errors;
