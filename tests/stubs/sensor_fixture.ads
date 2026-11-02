package Sensor_Fixture is
   Values : array (0 .. 16) of Natural := (others => 100);
   Read_Count : Natural := 0;
   Stop_On_Read : Natural := 0;
   Front_Sequence : array (1 .. 64) of Natural := (others => 30);
   Front_Length, Front_Index : Natural := 0;
   type Read_Event is record
      Pin : Natural := 0;
      Since_Servo_Aim : Duration := 0.0;
   end record;
   History : array (1 .. 128) of Read_Event;
end Sensor_Fixture;
