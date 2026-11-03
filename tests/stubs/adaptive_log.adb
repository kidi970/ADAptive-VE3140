-- Explicit host stub for the concrete UART binding. The bounded core is
-- exercised separately by logger_tests against a controlled clock/transport.
package body Adaptive_Log is
   procedure Put_Line (Message : String) is
      pragma Unreferenced (Message);
   begin
      null;
   end Put_Line;
   function Failed return Boolean is (False);
end Adaptive_Log;
