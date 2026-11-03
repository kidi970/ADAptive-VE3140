package body Adaptive_OLED_Codec is
   function Font (C : Character) return Glyph is
   begin
      case C is
         when '0' => return (16#3E#,16#51#,16#49#,16#45#,16#3E#);
         when '1' => return (0,16#42#,16#7F#,16#40#,0);
         when '2' => return (16#42#,16#61#,16#51#,16#49#,16#46#);
         when '3' => return (16#21#,16#41#,16#45#,16#4B#,16#31#);
         when '4' => return (16#18#,16#14#,16#12#,16#7F#,16#10#);
         when '5' => return (16#27#,16#45#,16#45#,16#45#,16#39#);
         when '6' => return (16#3C#,16#4A#,16#49#,16#49#,16#30#);
         when '7' => return (16#01#,16#71#,16#09#,16#05#,16#03#);
         when '8' => return (16#36#,16#49#,16#49#,16#49#,16#36#);
         when '9' => return (16#06#,16#49#,16#49#,16#29#,16#1E#);
         when 'A' => return (16#7E#,16#11#,16#11#,16#11#,16#7E#);
         when 'B' => return (16#7F#,16#49#,16#49#,16#49#,16#36#);
         when 'C' => return (16#3E#,16#41#,16#41#,16#41#,16#22#);
         when 'D' => return (16#7F#,16#41#,16#41#,16#22#,16#1C#);
         when 'E' => return (16#7F#,16#49#,16#49#,16#49#,16#41#);
         when 'F' => return (16#7F#,16#09#,16#09#,16#09#,16#01#);
         when 'G' => return (16#3E#,16#41#,16#49#,16#49#,16#7A#);
         when 'H' => return (16#7F#,16#08#,16#08#,16#08#,16#7F#);
         when 'I' => return (0,16#41#,16#7F#,16#41#,0);
         when 'J' => return (16#20#,16#40#,16#41#,16#3F#,16#01#);
         when 'K' => return (16#7F#,16#08#,16#14#,16#22#,16#41#);
         when 'L' => return (16#7F#,16#40#,16#40#,16#40#,16#40#);
         when 'M' => return (16#7F#,16#02#,16#0C#,16#02#,16#7F#);
         when 'N' => return (16#7F#,16#04#,16#08#,16#10#,16#7F#);
         when 'O' => return (16#3E#,16#41#,16#41#,16#41#,16#3E#);
         when 'P' => return (16#7F#,16#09#,16#09#,16#09#,16#06#);
         when 'Q' => return (16#3E#,16#41#,16#51#,16#21#,16#5E#);
         when 'R' => return (16#7F#,16#09#,16#19#,16#29#,16#46#);
         when 'S' => return (16#46#,16#49#,16#49#,16#49#,16#31#);
         when 'T' => return (16#01#,16#01#,16#7F#,16#01#,16#01#);
         when 'U' => return (16#3F#,16#40#,16#40#,16#40#,16#3F#);
         when 'V' => return (16#1F#,16#20#,16#40#,16#20#,16#1F#);
         when 'W' => return (16#3F#,16#40#,16#38#,16#40#,16#3F#);
         when 'X' => return (16#63#,16#14#,16#08#,16#14#,16#63#);
         when 'Y' => return (16#07#,16#08#,16#70#,16#08#,16#07#);
         when 'Z' => return (16#61#,16#51#,16#49#,16#45#,16#43#);
         when ':' => return (0,16#36#,16#36#,0,0);
         when '.' => return (0,16#60#,16#60#,0,0);
         when '-' => return (8,8,8,8,8);
         when '_' => return (16#40#,16#40#,16#40#,16#40#,16#40#);
         when others => return (others => 0);
      end case;
   end Font;
   function Encode_Line (Text : String) return Text_Line is
      Result : Text_Line := (1 => 16#40#, others => 0);
      Column : Positive := 2;
   begin
      for C of Text loop
         exit when Column + 5 > Result'Last;
         Result (Column .. Column + 4) := Font (C);
         Column := Column + 6;
      end loop;
      return Result;
   end Encode_Line;
end Adaptive_OLED_Codec;
