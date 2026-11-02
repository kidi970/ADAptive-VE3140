package MicroBit.DisplayRT is
   subtype Coord is Natural range 0 .. 4;
   type Matrix_Type is array (Coord, Coord) of Boolean;
   Pixels : Matrix_Type := (others => (others => False));
   procedure Set (X, Y : Coord);
   procedure Clear;
end MicroBit.DisplayRT;
