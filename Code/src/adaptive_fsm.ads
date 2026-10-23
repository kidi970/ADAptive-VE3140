with Adaptive_Policy; use Adaptive_Policy;
package Adaptive_FSM with Pure is
   type State is (Stopped, Verify, Cruise, Scan, Turn, Fault);
   type Event is (Recheck, Clear_Path, Unsafe_Path, Scan_Blocked,
                  Scan_Straight, Scan_Turn, Turn_Done, Fatal);
   function Next_State (Current : State; Input : Event) return State;
   procedure Confirm (Candidate : Choice; Previous : in out Choice;
                      Count : in out Natural; Accepted : out Boolean);
end Adaptive_FSM;
