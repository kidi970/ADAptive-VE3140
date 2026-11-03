-- Host-only adapter: the executable uses Ada.Text_IO, never board drivers.
with Ada.Text_IO;
with Ada.Integer_Text_IO;
with Adaptive_Policy;
procedure Replay_Policy is
   use Adaptive_Policy;
   A, B, C : Integer;
begin
   while not Ada.Text_IO.End_Of_File loop
      Ada.Integer_Text_IO.Get (A);
      Ada.Integer_Text_IO.Get (B);
      Ada.Integer_Text_IO.Get (C);
      Ada.Integer_Text_IO.Put
        (Integer (Filter (Distance (A), Distance (B), Distance (C))), Width => 0);
      Ada.Text_IO.New_Line;
   end loop;
end Replay_Policy;
