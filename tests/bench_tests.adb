with Ada.Text_IO; use Ada.Text_IO;
with Adaptive_Range_Model; use Adaptive_Range_Model;
with Adaptive_Bench_Model; use Adaptive_Bench_Model;
with Adaptive_OLED_Codec; use Adaptive_OLED_Codec;
with Adaptive_Bench_OLED;
with Ada.Unchecked_Conversion;
with Interfaces;
procedure Bench_Tests is
   Checks : Natural := 0;
   procedure Check (Condition : Boolean; Name : String) is
   begin
      Checks := Checks + 1;
      if not Condition then raise Program_Error with Name; end if;
   end Check;
   function Sample (D : Float; Valid : Boolean := True) return Echo_Result is
     (Status => (if Valid then Valid_Echo else No_Rise), Distance_CM => D,
      others => <>);
   function Window (D : Float) return Statistics is
     (Summarize ((others => Sample (D))));
   S : Statistics;
   Bound : Voltage_Bounds;
   Calls : Natural := 0;
   Fail_At : Natural := 0;
   Raise_At : Natural := 0;
   function From_Bits is new Ada.Unchecked_Conversion (Interfaces.Unsigned_32, Float);
   NaN : constant Float := From_Bits (16#7FC0_0000#);
   Infinity : constant Float := From_Bits (16#7F80_0000#);
   ACK_3C, ACK_3D : Boolean := False;
   Last_Address : Natural := 0;
   Last_Data : Text_Line := (others => 0);
   function Backend (Address_7bit : Positive; Data : Bytes) return Boolean is
   begin
      Calls := Calls + 1;
      if Calls = Raise_At then raise Program_Error with "mock OLED backend raised"; end if;
      Check (Address_7bit in 16#3C# .. 16#3D#, "no motor address allowed");
      Check (Data'Length <= 129, "bounded OLED payload");
      Check (Data (Data'First) in 0 | 16#40#, "OLED control byte");
      Last_Address := Address_7bit;
      if Data'Length = 129 then Last_Data := Data; end if;
      return (Fail_At = 0 or Calls /= Fail_At)
        and (if Address_7bit = 16#3C# then ACK_3C else ACK_3D);
   end Backend;
   package Screen is new Adaptive_Bench_OLED (Backend);
   Bus_Fails : Boolean := True;
   Bus_Init_Calls : Natural := 0;
   procedure Initialize_Bus is
   begin
      Bus_Init_Calls := Bus_Init_Calls + 1;
      if Bus_Fails then raise Program_Error with "mock I2C initialization failure"; end if;
   end Initialize_Bus;
   package Setup_Screen is new Adaptive_Bench_OLED (Backend, Initialize_Bus);
   OK : Boolean;
begin
   S := Summarize ((Sample (58.0), Sample (60.0), Sample (62.0)));
   Check (S.Valid_Count = 3 and S.Stable, "valid stable triple");
   Check (S.Mean = 60.0 and S.Median = 60.0, "mean and median");
   Check (S.Minimum = 58.0 and S.Spread = 4.0, "closest obstacle retained");
   Check (abs (S.Sample_SD - 2.0) < 0.0001, "sample SD uses n minus one");
   S := Summarize ((Sample (60.0), Sample (0.0, False), Sample (60.0)));
   Check (S.Valid_Count = 2 and not S.Stable, "missing echo vetoes triple");
   Check (Assess (S, Window (100.0), Window (100.0)) = Unknown, "missing front unknown");
   S := Summarize ((Sample (20.0), Sample (60.0), Sample (60.0)));
   Check (not S.Stable and S.Minimum = 20.0, "near outlier preserved and flagged");
   Check (Assess (S, Window (100.0), Window (100.0)) = Unknown, "unstable is not clear");
   for I in 0 .. 201 loop
      S := Window (Float (I));
      if I < 2 or I > 200 then
         Check (S.Valid_Count = 0 and not S.Stable, "range boundary rejects");
      elsif I <= 45 then
         Check (Assess (S, Window (100.0), Window (100.0)) = Stop, "front stop sweep");
      elsif I <= 60 then
         Check (Assess (S, Window (100.0), Window (100.0)) = Caution, "front caution sweep");
      else
         Check (Assess (S, Window (100.0), Window (100.0)) = Clear, "front clear sweep");
      end if;
      if I in 2 .. 200 then
         Check (Assess (Window (100.0), S, Window (100.0)) =
           (if I <= 15 then Stop elsif I <= 30 then Caution else Clear), "left sweep");
         Check (Assess (Window (100.0), Window (100.0), S) =
           (if I <= 15 then Stop elsif I <= 30 then Caution else Clear), "right sweep");
      end if;
   end loop;
   Check (abs (LED_Current_MA (3.3,1.9,1000.0) - 1.4) < 0.0001, "LED current model");
   Check (LED_Current_MA (3.3,3.5,1000.0) = 0.0, "no negative LED current");
   Bound := Divider_Bounds (4.75,5.25,1000.0,1200.0,0.05);
   Check (Bound.Low > 0.7 * 3.3 and Bound.High < 3.3, "conditional divider margin");
   Bound := Divider_Bounds (4.75,5.25,1200.0,1000.0,0.05);
   Check (Bound.Low < 0.7 * 3.3, "reversed divider not guaranteed high");
   begin
      Bound := Divider_Bounds (5.0,4.0,1000.0,1200.0,0.05);
      Check (False, "bad supply interval accepted");
   exception when Constraint_Error => Check (True, "bad supply rejected"); end;
   begin
      Bound := Divider_Bounds (5.0,5.0,1000.0,1200.0,1.0);
      Check (False, "100 percent tolerance accepted");
   exception when Constraint_Error => Check (True, "bad tolerance rejected"); end;
   begin
      OK := LED_Current_MA (3.3,1.9,0.0) > 0.0;
      Check (False, "zero LED resistor accepted");
   exception when Constraint_Error => Check (True, "zero resistor rejected"); end;
   Last_Data := Encode_Line ("A");
   Check (Last_Data (1) = 16#40# and Last_Data (2 .. 6) = Font ('A'), "OLED encoding");
   Check (Last_Data (7 .. 129) = (7 .. 129 => 0), "trailing pixels cleared");
   Check (Encode_Line ("") = (1 => 16#40#, 2 .. 129 => 0), "empty line clears row");
   Check (Encode_Line ("ABCDEFGHIJKLMNOPQRSTUV") =
          Encode_Line ("ABCDEFGHIJKLMNOPQRSTU"), "long text bounded to 21 cells");
   Check (not Screen.Initialize and Calls = 2 and not Screen.Ready,
          "absent OLED is bounded and nonfatal");
   Calls := 0;
   Check (not Screen.Show_Line (0,"NO DEVICE") and Calls = 0, "offline OLED no writes");
   ACK_3D := True;
   Check (Screen.Initialize and Screen.Ready and Screen.Address = 16#3D#,
          "alternate address supported");
   Check (Last_Address = 16#3D#, "7 bit address retained");
   Calls := 0;
   Check (Screen.Show_Line (7,"UNKNOWN") and Calls = 2, "page and data writes");
   Check (Last_Data = Encode_Line ("UNKNOWN"), "rendered payload reaches backend");
   begin
      OK := Screen.Show_Line (8,"BAD");
      Check (False, "bad page accepted");
   exception when Constraint_Error => Check (True, "invalid page rejected"); end;
   Fail_At := Calls + 1;
   Check (not Screen.Show_Line (0,"BUS FAILURE") and not Screen.Ready,
          "I2C failure invalidates OLED state");
   Calls := 0; Fail_At := 4; ACK_3C := True;
   Check (not Screen.Initialize and Calls = 4 and not Screen.Ready,
          "initialization aborts at first bus failure");
   S := Summarize ((Sample (60.0), Sample (NaN), Sample (60.0)));
   Check (S.Valid_Count = 2 and abs (S.Valid_Fraction - 2.0 / 3.0) < 0.00001,
          "NaN rejected with explicit valid fraction");
   Check (Assess (S, Window (100.0), Window (100.0)) = Unknown, "NaN window unknown");
   for Bad of Readings'(Sample (Infinity), Sample (-Infinity), Sample (0.0)) loop
      S := Summarize ((others => Bad));
      Check (S.Valid_Count = 0 and S.Valid_Fraction = 0.0 and not S.Stable,
             "nonfinite or zero raw range rejected");
   end loop;
   for Status in Echo_Status loop
      if Status /= Valid_Echo then
         S := Summarize ((others => (Status => Status, Distance_CM => 100.0, others => <>)));
         Check (S.Valid_Count = 0 and Assess (S, Window (100.0), Window (100.0)) = Unknown,
                "status failure cannot become clear distance");
      end if;
   end loop;
   S := Window (100.0); S.Minimum := NaN;
   Check (Assess (S, Window (100.0), Window (100.0)) = Unknown, "forged NaN minimum unknown");
   S := Window (100.0); S.Spread := Infinity;
   Check (Assess (S, Window (100.0), Window (100.0)) = Unknown, "infinite spread unknown");
   S := Window (100.0); S.Sample_SD := NaN;
   Check (Assess (S, Window (100.0), Window (100.0)) = Unknown, "NaN dispersion unknown");
   S := Summarize ((Sample (50.0), Sample (57.0), Sample (65.0)));
   Check (S.Stable and S.Spread = 15.0, "inclusive spread limit");
   S := Summarize ((Sample (50.0), Sample (57.0), Sample (65.01)));
   Check (not S.Stable, "spread above limit rejected");
   begin
      OK := LED_Current_MA (NaN, 1.9, 1000.0) > 0.0;
      Check (False, "NaN LED supply accepted");
   exception when Constraint_Error => Check (True, "NaN LED supply rejected"); end;
   begin
      OK := LED_Current_MA (3.3, 1.9, Infinity) > 0.0;
      Check (False, "infinite LED resistance accepted");
   exception when Constraint_Error => Check (True, "infinite LED resistance rejected"); end;
   begin
      Bound := Divider_Bounds (4.75, 5.25, 5100.0, 6800.0, NaN);
      Check (False, "NaN divider tolerance accepted");
   exception when Constraint_Error => Check (True, "NaN divider tolerance rejected"); end;
   begin
      Bound := Divider_Bounds (4.75, Infinity, 5100.0, 6800.0, 0.05);
      Check (False, "infinite divider supply accepted");
   exception when Constraint_Error => Check (True, "infinite divider supply rejected"); end;
   Bound := Divider_Bounds (4.75, 5.25, 5100.0, 6800.0, 0.05);
   Check (abs (Bound.Low - 2.5971223) < 0.00001
          and abs (Bound.High - 3.1276596) < 0.00001, "available resistor pair bounds");
   Bound := Divider_Bounds (5.0, 5.0, Float'Last, Float'Last, 0.0);
   Check (Bound.Low = 2.5 and Bound.High = 2.5, "ratio avoids finite resistor overflow");
   Check (Encode_Line ((100 .. 120 => 'A')) = Encode_Line ((1 .. 21 => 'A')),
          "text indexes need not start at one");
   Calls := 0; Fail_At := 0; Raise_At := 1;
   Check (not Screen.Initialize and not Screen.Ready and Calls = 1,
          "probing exception contained without second probe");
   Calls := 0; Raise_At := 3;
   Check (not Screen.Initialize and not Screen.Ready and Calls = 3,
          "initialization write exception contained");
   Calls := 0; Raise_At := 0;
   Check (Screen.Initialize and Screen.Ready, "explicit bench reinitialization recovers mock");
   Calls := 0; Raise_At := 2;
   Check (not Screen.Show_Line (0, "EXCEPTION") and not Screen.Ready and Calls = 2,
          "data write exception invalidates ready state");
   Calls := 0;
   Check (not Screen.Show_Line (0, "NO RETRY") and Calls = 0,
          "failed OLED suppresses later writes");
   Raise_At := 0;
   Check (not Setup_Screen.Initialize and not Setup_Screen.Ready
          and Bus_Init_Calls = 1 and Calls = 0,
          "I2C initialization exception contained before first transaction");
   Bus_Fails := False;
   Check (Setup_Screen.Initialize and Setup_Screen.Ready and Bus_Init_Calls = 2,
          "explicit setup after mock bus recovery");
   Put_Line ("PASS bench model/OLED:" & Natural'Image (Checks) & " checks");
end Bench_Tests;
