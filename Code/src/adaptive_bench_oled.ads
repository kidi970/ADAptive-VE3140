with Adaptive_OLED_Codec;
generic
   with function Write (Address_7bit : Positive;
                        Data : Adaptive_OLED_Codec.Bytes) return Boolean;
   with procedure Initialize_Bus is null;
package Adaptive_Bench_OLED is
   function Initialize return Boolean;
   function Ready return Boolean;
   function Address return Natural;
   function Show_Line (Page : Natural; Text : String) return Boolean;
   -- Bus setup and backend writes must be bounded. Missing OLED is a reported
   -- peripheral failure, not an exception that prevents sensor diagnosis.
end Adaptive_Bench_OLED;
