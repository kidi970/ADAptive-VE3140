with HAL; use HAL;
with HAL.I2C; use HAL.I2C;
with Ada.Real_Time;
package MicroBit.I2C is
   type Speed is (S100kbps, S250kbps, S400kbps);
   procedure InitializeExt (S : Speed);
   function InitializedExt return Boolean;
   function ControllerExt return not null Any_I2C_Port;

   Calls : Natural := 0;
   Fail_At : Natural := 0;
   Inject_Status : I2C_Status := Err_Timeout;
   Stop_During_Write : Boolean := False;
   Last_Servo_Aim : Ada.Real_Time.Time := Ada.Real_Time.Clock;
   type Trace_Item is record
      Register, Value : UInt8 := 0;
      Length, Timeout : Natural := 0;
   end record;
   Trace : array (1 .. 512) of Trace_Item;
   Last_Data : I2C_Data (0 .. 64) := (others => 0);
   procedure Reset_Trace;
private
   type Fake_Port is new I2C_Port with null record;
   overriding procedure Master_Transmit
     (This : in out Fake_Port; Addr : I2C_Address; Data : I2C_Data;
      Status : out I2C_Status; Timeout : Natural := 1000);
   overriding procedure Master_Receive
     (This : in out Fake_Port; Addr : I2C_Address; Data : out I2C_Data;
      Status : out I2C_Status; Timeout : Natural := 1000);
   overriding procedure Mem_Write
     (This : in out Fake_Port; Addr : I2C_Address; Mem_Addr : UInt16;
      Mem_Addr_Size : I2C_Memory_Address_Size; Data : I2C_Data;
      Status : out I2C_Status; Timeout : Natural := 1000);
   overriding procedure Mem_Read
     (This : in out Fake_Port; Addr : I2C_Address; Mem_Addr : UInt16;
      Mem_Addr_Size : I2C_Memory_Address_Size; Data : out I2C_Data;
      Status : out I2C_Status; Timeout : Natural := 1000);
   overriding procedure Mem_Write_Buffer
     (This : in out Fake_Port; Addr : I2C_Address; Data : I2C_Data;
      Status : out I2C_Status; Timeout : Natural := 1000);
end MicroBit.I2C;
