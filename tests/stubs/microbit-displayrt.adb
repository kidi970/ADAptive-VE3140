package body MicroBit.DisplayRT is
   procedure Set (X, Y : Coord) is
   begin
      Pixels (X, Y) := True;
   end Set;
   procedure Clear is
   begin
      Pixels := (others => (others => False));
   end Clear;
end MicroBit.DisplayRT;
