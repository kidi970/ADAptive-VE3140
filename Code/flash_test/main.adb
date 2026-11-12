with Ada.Real_Time;        use Ada.Real_Time;
with MicroBit;
with MicroBit.Ultrasonic;
with MicroBit.Types;       use MicroBit.Types;
with MicroBit.Console;     use MicroBit.Console;
with MicroBit.Music; use MicroBit.Music;

procedure Main is

   -- Ultrasonic sensor: Trigger P13, Echo P1
   package Front_Sensor is new MicroBit.Ultrasonic
     (MicroBit.MB_P13, MicroBit.MB_P1);

   Reading_1 : Distance_cm := 0;
   Reading_2 : Distance_cm := 0;
   Reading_3 : Distance_cm := 0;

   Distance_Front : Distance_cm := 0;
   Pip : constant Melody := (1 => (C6, 70));
   Pipintervall : Duration;
   Sist_Pip : Time := Time_First;

   -- Filter measurements
   function Median
     (A, B, C : Distance_cm) return Distance_cm
   is
      function Valid (D : Distance_cm) return Boolean is
      begin
         return D >= 2 and then D <= 200;
      end Valid;

      function Close
        (X, Y : Distance_cm) return Boolean
      is
      begin
         return
           (X >= Y and then X - Y <= 15)
           or else
           (Y > X and then Y - X <= 15);
      end Close;

      Result : Distance_cm := 0;

   begin
      if Valid (A) and then Valid (B)
        and then Close (A, B)
      then
         Result := Distance_cm'Min (A, B);
      end if;

      if Valid (A) and then Valid (C)
        and then Close (A, C)
      then
         if Result = 0 then
            Result := Distance_cm'Min (A, C);
         else
            Result := Distance_cm'Min
              (Result, Distance_cm'Min (A, C));
         end if;
      end if;

      if Valid (B) and then Valid (C)
        and then Close (B, C)
      then
         if Result = 0 then
            Result := Distance_cm'Min (B, C);
         else
            Result := Distance_cm'Min
              (Result, Distance_cm'Min (B, C));
         end if;
      end if;

      return Result;
   end Median;

   function FareIndikasjon (Distance : Distance_cm) return Duration is
   begin
      if Distance = 0 then
         return 0.0;
      elsif Distance <= 15 then
         return 0.14;
      elsif Distance <= 30 then
         return 0.40;
      elsif Distance <= 45 then
         return 0.82;
      else
         return 0.0;
      end if;
   end FareIndikasjon;

   -- Read sensor three times
   function Measure return Distance_cm is
   begin
      delay until Clock + Milliseconds (70);
      Reading_1 := Front_Sensor.Read;

      delay until Clock + Milliseconds (70);
      Reading_2 := Front_Sensor.Read;

      delay until Clock + Milliseconds (70);
      Reading_3 := Front_Sensor.Read;

      return Median
        (Reading_1, Reading_2, Reading_3);
   end Measure;

begin

   Put_Line ("Ultrasonic Sensor Test");

   loop

      Distance_Front := Measure;
      Put_Line
        ("FRONT:" & Distance_cm'Image (Distance_Front));

      Pipintervall := FareIndikasjon (Distance_Front);
      if Pipintervall = 0.0 then
         Sist_Pip := Time_First;
      elsif Sist_Pip = Time_First
        or else Clock >= Sist_Pip + To_Time_Span (Pipintervall)
      then
         Sist_Pip := Clock;
         Play (27, Pip);
      end if;
   end loop;

end Main;
