package body Adaptive_Lamp_Control is
   protected body State is
      procedure Enable is
      begin
         Active := True;
      end Enable;
      procedure Set_Mode (Mode : Lamp_Mode) is
      begin
         if Current /= Faulted then Current := Mode; end if;
      end Set_Mode;
      procedure Latch_Fault is
      begin
         Current := Faulted;
      end Latch_Fault;
      procedure Task_Failed is
      begin
         Worker_Failed := True;
         Current := Faulted;
      end Task_Failed;
      procedure Read (Enabled : out Boolean; Mode : out Lamp_Mode;
                      Failed : out Boolean) is
      begin
         Enabled := Active; Mode := Current; Failed := Worker_Failed;
      end Read;
   end State;
end Adaptive_Lamp_Control;
