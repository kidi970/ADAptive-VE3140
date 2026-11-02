with Sensor_Fixture;
with Adaptive_Safety;
with MicroBit.I2C;
with Ada.Real_Time; use Ada.Real_Time;
package body MicroBit.Ultrasonic is
   function Read return Natural is
   begin
      Sensor_Fixture.Read_Count := Sensor_Fixture.Read_Count + 1;
      Sensor_Fixture.History (Sensor_Fixture.Read_Count) :=
        (Echo_Pin, To_Duration (Clock - MicroBit.I2C.Last_Servo_Aim));
      if Sensor_Fixture.Read_Count = Sensor_Fixture.Stop_On_Read then
         Adaptive_Safety.Request_Stop;
      end if;
      if Echo_Pin = 1 and Sensor_Fixture.Front_Length > 0 then
         Sensor_Fixture.Front_Index := Sensor_Fixture.Front_Index + 1;
         if Sensor_Fixture.Front_Index <= Sensor_Fixture.Front_Length then
            return Sensor_Fixture.Front_Sequence (Sensor_Fixture.Front_Index);
         end if;
      end if;
      return Sensor_Fixture.Values (Echo_Pin);
   end Read;
end MicroBit.Ultrasonic;
