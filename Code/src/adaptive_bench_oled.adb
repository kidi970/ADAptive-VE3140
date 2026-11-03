with Adaptive_OLED_Codec; use Adaptive_OLED_Codec;
package body Adaptive_Bench_OLED is
   Active_Address : Natural := 0;
   Is_Ready : Boolean := False;
   function Ready return Boolean is (Is_Ready);
   function Address return Natural is (Active_Address);
   function Send (Data : Bytes) return Boolean is
   begin
      if Active_Address = 0 then return False; end if;
      if not Write (Active_Address, Data) then
         Is_Ready := False; return False;
      end if;
      return True;
   exception
      when others => Is_Ready := False; return False;
   end Send;
   function Show_Line (Page : Natural; Text : String) return Boolean is
   begin
      if Page > 7 then raise Constraint_Error with "OLED page outside 0..7"; end if;
      if not Is_Ready then return False; end if;
      return Send ((16#00#, Byte (16#B0# + Page), 16#00#, 16#10#))
        and then Send (Encode_Line (Text));
   end Show_Line;
   function Initialize return Boolean is
   begin
      Is_Ready := False; Active_Address := 0;
      Initialize_Bus;
      -- Write only to the two SSD1306 addresses; never scan the motor board.
      for Candidate in 16#3C# .. 16#3D# loop
         if Write (Candidate, (16#00#,16#AE#)) then
            Active_Address := Candidate; exit;
         end if;
      end loop;
      if Active_Address = 0 then return False; end if;
      if not Send ((16#00#,16#AE#,16#D5#,16#80#,16#A8#,16#3F#,
                    16#D3#,0,16#40#,16#8D#,16#14#,16#20#,16#02#,
                    16#A1#,16#C8#,16#DA#,16#12#,16#81#,16#80#,
                    16#D9#,16#F1#,16#DB#,16#40#,16#A4#,16#A6#))
      then return False; end if;
      Is_Ready := True;
      for Page in 0 .. 7 loop
         if not Show_Line (Page, "") then return False; end if;
      end loop;
      return Send ((16#00#,16#AF#));
   exception
      when others => Is_Ready := False; return False;
   end Initialize;
end Adaptive_Bench_OLED;
