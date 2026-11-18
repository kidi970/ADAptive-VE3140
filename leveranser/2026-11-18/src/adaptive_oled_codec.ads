package Adaptive_OLED_Codec with Pure is
   type Byte is mod 2 ** 8;
   type Bytes is array (Positive range <>) of Byte;
   subtype Glyph is Bytes (1 .. 5);
   subtype Text_Line is Bytes (1 .. 129);
   function Font (C : Character) return Glyph;
   function Encode_Line (Text : String) return Text_Line;
   -- 128 pixels, page addressing, at most 21 six-column characters.
   -- Byte 1 is the SSD1306 data control byte 0x40; unused pixels are zero.
end Adaptive_OLED_Codec;
