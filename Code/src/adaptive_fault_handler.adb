package body Adaptive_Fault_Handler is
   use Ada.Exceptions;
   Saved : Fault_Status;

   function Status return Fault_Status is (Saved);

   procedure Handle (Occurrence : Exception_Occurrence) is
      Stop_Id : Exception_Id := Null_Id;
   begin
      -- Preserve the first cause and bound recovery to one stop attempt.
      if Saved.Latched then return; end if;
      Saved.Latched := True;
      Saved.Primary := Adaptive_Errors.Classify (Exception_Identity (Occurrence));
      Latch_Stop;
      begin
         Stop_Motors;
         Saved.Stop_Command := Acknowledged;
      exception
         when Stop_Error : others =>
            Saved.Stop_Command := Failed;
            Stop_Id := Exception_Identity (Stop_Error);
            Saved.Stop_Fault := Adaptive_Errors.Classify (Stop_Id);
      end;
      -- Logging is always after the stop attempt. A failing logger must not
      -- escape the recovery boundary or cause an automatic restart.
      begin
         Log ("FAULT LATCHED " & Adaptive_Errors.Fault_Code'Image (Saved.Primary)
              & " " & Exception_Name (Occurrence)
              & " " & Exception_Message (Occurrence));
         Log ("STOP COMMAND " & Stop_Result'Image (Saved.Stop_Command));
         if Saved.Stop_Command = Failed then
            Log ("STOP UNCONFIRMED " & Exception_Name (Stop_Id)
                 & "; DISCONNECT MOTOR POWER");
         end if;
      exception
         when others => Saved.Logging_Failed := True;
      end;
   end Handle;
end Adaptive_Fault_Handler;
