with Ada.Text_IO; use Ada.Text_IO;
with Adaptive_USB_IO_Core;
procedure USB_IO_Tests is
   Checks : Natural := 0;
   type Action is (Write_Pin, Output_Mode, Input_Mode, Read_Pin);
   type Operation is record
      Kind : Action; Pin : Natural; High : Boolean;
   end record;
   Trace : array (1 .. 100) of Operation;
   Count : Natural := 0;
   Levels : array (0 .. 47) of Boolean := (others => True);
   Outputs : array (0 .. 47) of Boolean := (others => False);
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if not Condition then raise Program_Error with Name; end if;
      Checks := Checks + 1;
   end Check;
   procedure Record_Operation (Kind : Action; Pin : Natural; High : Boolean := False) is
   begin
      Check (Pin in 11 | 14 | 15 | 19 | 21 | 22 | 23 | 24 | 28 | 30 | 31 | 37,
             "only built-in matrix and button pins allowed");
      Count := Count + 1; Trace (Count) := (Kind, Pin, High);
   end Record_Operation;
   procedure Configure_Input (Pin : Natural) is
   begin
      Check (Pin in 14 | 23, "only A/B configured as inputs");
      Record_Operation (Input_Mode, Pin);
   end Configure_Input;
   procedure Configure_Output (Pin : Natural) is
   begin
      Check (Pin in 11 | 15 | 19 | 21 | 22 | 24 | 28 | 30 | 31 | 37,
             "buttons never configured as outputs");
      Check (Count > 0 and then Trace (Count).Kind = Write_Pin
             and then Trace (Count).Pin = Pin, "latch preloaded before direction");
      if Pin in 28 | 11 | 31 | 37 | 30 then
         Check (Outputs (21) and Outputs (22) and Outputs (15)
                and Outputs (24) and Outputs (19)
                and not Levels (21) and not Levels (22) and not Levels (15)
                and not Levels (24) and not Levels (19), "rows disabled before any column setup");
      end if;
      Outputs (Pin) := True;
      Record_Operation (Output_Mode, Pin);
   end Configure_Output;
   procedure Write_Level (Pin : Natural; High : Boolean) is
   begin
      Levels (Pin) := High;
      Record_Operation (Write_Pin, Pin, High);
   end Write_Level;
   function Read_Level (Pin : Natural) return Boolean is
   begin
      Record_Operation (Read_Pin, Pin); return Levels (Pin);
   end Read_Level;
   procedure Broken_Output (Pin : Natural) is
      pragma Unreferenced (Pin);
   begin
      raise Program_Error with "mock GPIO setup failed";
   end Broken_Output;
   package Board is new Adaptive_USB_IO_Core
     (Configure_Input, Configure_Output, Write_Level, Read_Level);
   package Broken is new Adaptive_USB_IO_Core
     (Configure_Input, Broken_Output, Write_Level, Read_Level);
   Before : Natural;
   Raised : Boolean;
begin
   Check (Count = 0, "no callbacks during elaboration");
   Raised := False;
   begin
      Board.Center_On;
   exception when Program_Error => Raised := True; end;
   Check (Raised and Count = 0, "uninitialized output inhibited");
   Board.Initialize;
   Check (Count = 22, "bounded initialization operations");
   Check (not Levels (21) and not Levels (22) and not Levels (15)
          and not Levels (24) and not Levels (19), "every row initially off");
   Check (Levels (28) and Levels (11) and Levels (31)
          and Levels (37) and Levels (30), "every column initially off");
   Before := Count; Board.Initialize;
   Check (Count = Before, "repeat initialization makes no writes");
   Board.Center_On;
   Check (Count = Before + 3 and not Trace (Before + 1).High
          and Trace (Before + 1).Pin = 15
          and Trace (Before + 2).Pin = 31 and not Trace (Before + 2).High
          and Trace (Before + 3).Pin = 15 and Trace (Before + 3).High,
          "source row disabled before centre column and then enabled");
   Check (Levels (15) and not Levels (31)
          and not Levels (21) and not Levels (22)
          and not Levels (24) and not Levels (19), "only centre row active");
   Board.Center_Off;
   Check (not Levels (15) and Levels (31), "centre off restores both latches");
   Check (Trace (Count - 1).Pin = 15 and not Trace (Count - 1).High,
          "source row disabled before restoring column");
   Check (not Board.Button_A_Pressed, "active-low A released");
   Levels (14) := False;
   Check (Board.Button_A_Pressed, "active-low A pressed");
   Check (not Board.Button_B_Pressed, "active-low B released");
   Levels (23) := False;
   Check (Board.Button_B_Pressed, "active-low B pressed");
   Raised := False;
   begin
      Broken.Initialize;
   exception when Program_Error => Raised := True; end;
   Check (Raised, "setup failure propagated to supervisor");
   Before := Count;
   Raised := False;
   begin
      Broken.Center_On;
   exception when Program_Error => Raised := True; end;
   Check (Raised and Count = Before, "partial setup cannot enable centre output");
   Put_Line ("PASS" & Natural'Image (Checks) & " USB status IO checks (mock GPIO)");
end USB_IO_Tests;
