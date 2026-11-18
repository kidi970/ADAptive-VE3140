with Ada.Real_Time; use Ada.Real_Time;
package body Adaptive_Log_Core is
   Disabled : Boolean := False;
   Truncated : Boolean := False;
   function Failed return Boolean is (Disabled);
   function Truncated_Last_Line return Boolean is (Truncated);

   function Try_Line (Message : String) return Boolean is
      Started : Time;
      Polls : Natural := 0;
      Count : Natural := 0;
      Limit : Natural := Max_Line_Length;
      function Send (C : Character) return Boolean is
         Now : Time;
      begin
         loop
            if Polls = Poll_Limit then return False; end if;
            Polls := Polls + 1;
            Now := Clock;
            if Now < Started
              or else Now - Started >= Milliseconds (Line_Budget_Ms)
            then return False; end if;
            exit when Ready;
         end loop;
         Write_Byte (C);
         return True;
      end Send;
   begin
      if Disabled then return False; end if;
      Started := Clock;
      Truncated := Message'Length > Max_Line_Length;
      if Truncated then Limit := Max_Line_Length - 3; end if;
      for C of Message loop
         exit when Count = Limit;
         -- Text is one record. Embedded controls must not forge log records.
         if not Send ((if C in ASCII.NUL | ASCII.CR | ASCII.LF then '?' else C)) then
            Disabled := True; return False;
         end if;
         Count := Count + 1;
      end loop;
      if Truncated then
         for I in 1 .. 3 loop
            if not Send ('.') then Disabled := True; return False; end if;
         end loop;
      end if;
      if not Send (ASCII.CR) or else not Send (ASCII.LF) then
         Disabled := True; return False;
      end if;
      return True;
   exception
      when others => Disabled := True; return False;
   end Try_Line;
end Adaptive_Log_Core;
