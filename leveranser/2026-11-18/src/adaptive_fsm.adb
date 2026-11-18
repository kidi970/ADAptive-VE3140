package body Adaptive_FSM is
   function Next_State (Current : State; Input : Event) return State is
   begin
      if Current = Fault or Input = Fatal then return Fault; end if;
      case Current is
         when Stopped =>
            if Input = Recheck then return Verify; end if;
         when Verify =>
            if Input = Clear_Path then return Cruise;
            elsif Input = Unsafe_Path then return Scan; end if;
         when Cruise =>
            if Input = Unsafe_Path then return Stopped;
            elsif Input = Clear_Path then return Cruise; end if;
         when Scan =>
            if Input = Scan_Straight then return Verify;
            elsif Input = Scan_Turn then return Turn;
            elsif Input = Scan_Blocked then return Stopped; end if;
         when Turn =>
            if Input = Turn_Done then return Verify;
            elsif Input = Unsafe_Path then return Stopped; end if;
         when Fault => null;
      end case;
      -- Unexpected events must not preserve an active motion state.
      return Stopped;
   end Next_State;
   procedure Confirm (Candidate : Choice; Previous : in out Choice;
                      Count : in out Natural; Accepted : out Boolean) is
   begin
      if Candidate not in Left | Right then
         Previous := Blocked; Count := 0;
      elsif Previous = Candidate then
         Count := Natural'Min (Count, 1) + 1;
      else
         Previous := Candidate; Count := 1;
      end if;
      Accepted := Count = 2;
      if Accepted then Previous := Blocked; Count := 0; end if;
   end Confirm;
end Adaptive_FSM;
