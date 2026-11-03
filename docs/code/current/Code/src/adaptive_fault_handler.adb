package body Adaptive_Fault_Handler is
   use Ada.Exceptions;
   use type Adaptive_Errors.Fault_Code;
   Saved : Fault_Status;

   function Status return Fault_Status is (Saved);

   procedure Handle (Occurrence : Exception_Occurrence) is
      Stop_Id : Exception_Id := Null_Id;
   begin
      -- Preserve the first cause and bound recovery to one stop attempt.
      if Saved.Latched then return; end if;
      Saved.Latched := True;
      Saved.Primary := Adaptive_Errors.Classify (Exception_Identity (Occurrence));
      begin
         Latch_Stop;
      exception
         when Latch_Error : others =>
            Saved.Latch_Fault :=
              Adaptive_Errors.Classify (Exception_Identity (Latch_Error));
      end;
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
         -- Avoid concatenating both unconstrained exception strings on the
         -- small secondary stack. The concrete logger bounds each record.
         Log ("FAULT LATCHED " & Adaptive_Errors.Fault_Code'Image (Saved.Primary));
         Log (Exception_Name (Occurrence));
         Log (Exception_Message (Occurrence));
         if Saved.Latch_Fault /= Adaptive_Errors.No_Fault then
            Log ("STOP LATCH ERROR " &
                 Adaptive_Errors.Fault_Code'Image (Saved.Latch_Fault));
         end if;
         Log ("STOP COMMAND " & Stop_Result'Image (Saved.Stop_Command));
         if Saved.Stop_Command = Failed then
            Log ("STOP UNCONFIRMED");
            Log (Exception_Name (Stop_Id));
            Log ("DISCONNECT MOTOR POWER");
         end if;
      exception
         when others => Saved.Logging_Failed := True;
      end;
   end Handle;
end Adaptive_Fault_Handler;
