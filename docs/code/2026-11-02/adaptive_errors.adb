package body Adaptive_Errors is
   use type Ada.Exceptions.Exception_Id;
   function Classify (Id : Ada.Exceptions.Exception_Id) return Fault_Code is
   begin
      if Id = Motor_Bus_Error'Identity then return Motor_Bus_Fault;
      elsif Id = Motor_Not_Ready'Identity then return Initialization_Fault;
      elsif Id = Servo_Limit_Error'Identity then return Servo_Range_Fault;
      elsif Id = Stop_Latched_Error'Identity then return Stop_Latch_Fault;
      elsif Id = Safety_Setup_Error'Identity then return Safety_Setup_Fault;
      elsif Id = Constraint_Error'Identity then return Constraint_Fault;
      elsif Id = Program_Error'Identity then return Program_Fault;
      elsif Id = Storage_Error'Identity then return Storage_Fault;
      else return Unexpected_Fault;
      end if;
   end Classify;
end Adaptive_Errors;
