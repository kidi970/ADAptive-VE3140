with Adaptive_Safety;
package body MicroBit.I2C is
   Port : aliased Fake_Port;
   Initialized : Boolean := False;
   procedure InitializeExt (S : Speed) is
      pragma Unreferenced (S);
   begin
      Initialized := True;
   end InitializeExt;
   function InitializedExt return Boolean is (Initialized);
   function ControllerExt return not null Any_I2C_Port is (Port'Access);
   procedure Reset_Trace is
   begin
      Calls := 0; Fail_At := 0; Stop_During_Write := False;
   end Reset_Trace;
   overriding procedure Master_Transmit
     (This : in out Fake_Port; Addr : I2C_Address; Data : I2C_Data;
      Status : out I2C_Status; Timeout : Natural := 1000) is
      pragma Unreferenced (This);
   begin
      pragma Assert (Addr in 16#80# | 16#78#);
      Calls := Calls + 1;
      if Addr = 16#80# and Data (Data'First) = 16#3E# then
         Last_Servo_Aim := Ada.Real_Time.Clock;
      end if;
      Last_Data := (others => 0);
      for I in Data'Range loop Last_Data (I - Data'First) := Data (I); end loop;
      Trace (Calls) := (Data (Data'First), Data (Data'First + 1),
                        Data'Length, Timeout);
      if Stop_During_Write then
         Adaptive_Safety.Request_Stop;
         Stop_During_Write := False;
      end if;
      Status := (if Calls = Fail_At then Inject_Status else Ok);
   end Master_Transmit;
   overriding procedure Master_Receive
     (This : in out Fake_Port; Addr : I2C_Address; Data : out I2C_Data;
      Status : out I2C_Status; Timeout : Natural := 1000) is
   begin
      raise Program_Error with "Unexpected receive in motion test";
   end Master_Receive;
   overriding procedure Mem_Write
     (This : in out Fake_Port; Addr : I2C_Address; Mem_Addr : UInt16;
      Mem_Addr_Size : I2C_Memory_Address_Size; Data : I2C_Data;
      Status : out I2C_Status; Timeout : Natural := 1000) is
   begin
      raise Program_Error with "Unexpected memory write in motion test";
   end Mem_Write;
   overriding procedure Mem_Read
     (This : in out Fake_Port; Addr : I2C_Address; Mem_Addr : UInt16;
      Mem_Addr_Size : I2C_Memory_Address_Size; Data : out I2C_Data;
      Status : out I2C_Status; Timeout : Natural := 1000) is
   begin
      raise Program_Error with "Unexpected memory read in motion test";
   end Mem_Read;
   overriding procedure Mem_Write_Buffer
     (This : in out Fake_Port; Addr : I2C_Address; Data : I2C_Data;
      Status : out I2C_Status; Timeout : Natural := 1000) is
   begin
      raise Program_Error with "Unexpected buffered write in motion test";
   end Mem_Write_Buffer;
end MicroBit.I2C;
