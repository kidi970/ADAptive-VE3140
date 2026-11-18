with Ada.Real_Time;
generic
   with function Clock return Ada.Real_Time.Time;
   with function Ready return Boolean;
   with procedure Write_Byte (C : Character);
   Line_Budget_Ms : Positive := 30;
   Poll_Limit : Positive := 100_000;
package Adaptive_Log_Core is
   Max_Line_Length : constant := 160;
   -- Single foreground writer. No allocation or hardware access at elaboration.
   -- The callbacks must themselves be bounded and nonblocking. A poll bound
   -- remains effective if the injected clock stops advancing.
   function Try_Line (Message : String) return Boolean;
   function Failed return Boolean;
   function Truncated_Last_Line return Boolean;
end Adaptive_Log_Core;
