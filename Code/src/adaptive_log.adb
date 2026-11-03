with Ada.Real_Time;
with HAL; use HAL;
with NRF_SVD.UART;
with Adaptive_Log_Core;
package body Adaptive_Log is
   Initialized : Boolean := False;
   Initialization_Failed : Boolean := False;
   function Ready return Boolean is
     (NRF_SVD.UART.UART0_Periph.EVENTS_TXDRDY /= 0);
   procedure Write_Byte (C : Character) is
   begin
      NRF_SVD.UART.UART0_Periph.EVENTS_TXDRDY := 0;
      NRF_SVD.UART.UART0_Periph.TXD.TXD := UInt8 (Character'Pos (C));
   end Write_Byte;
   package Core is new Adaptive_Log_Core
     (Ada.Real_Time.Clock, Ready, Write_Byte);
   function Failed return Boolean is
     (Initialization_Failed or else Core.Failed);
   procedure Put_Line (Message : String) is
      Sent : Boolean;
      pragma Unreferenced (Sent);
   begin
      if Failed then return; end if;
      if not Initialized then
         -- Explicit lazy initialization: importing this package performs no
         -- UART transaction. Avoid the ADL Transmit routine, whose Timeout
         -- argument is ignored by this pinned Nordic driver.
         -- micro:bit V2 board map: internal USB bridge TX=P0.06, RX=P1.08.
         -- The register constant is the pinned nRF.UART.Baud115200 value.
         -- Avoid nRF.Device: its tagged TWI_0/TWI_1 objects pull the entire
         -- I2C driver into an otherwise isolated USB test.
         NRF_SVD.UART.UART0_Periph.BAUDRATE := 16#01D7E000#;
         NRF_SVD.UART.UART0_Periph.CONFIG.PARITY := NRF_SVD.UART.Excluded;
         NRF_SVD.UART.UART0_Periph.CONFIG.HWFC := NRF_SVD.UART.Disabled;
         NRF_SVD.UART.UART0_Periph.PSELRTS := 16#FFFF_FFFF#;
         NRF_SVD.UART.UART0_Periph.PSELCTS := 16#FFFF_FFFF#;
         NRF_SVD.UART.UART0_Periph.PSELTXD := 6;
         NRF_SVD.UART.UART0_Periph.PSELRXD := 40;
         NRF_SVD.UART.UART0_Periph.EVENTS_TXDRDY := 0;
         NRF_SVD.UART.UART0_Periph.ENABLE.ENABLE := NRF_SVD.UART.Enabled;
         NRF_SVD.UART.UART0_Periph.TASKS_STARTRX := 1;
         NRF_SVD.UART.UART0_Periph.TASKS_STARTTX := 1;
         -- Match the pinned Nordic driver's initial byte which primes the
         -- TXDRDY handshake. Successful logging means accepted by TXD, not
         -- proof that a USB host received the text.
         NRF_SVD.UART.UART0_Periph.TXD.TXD := 0;
         Initialized := True;
      end if;
      Sent := Core.Try_Line (Message);
   exception
      when others => Initialization_Failed := True;
   end Put_Line;
end Adaptive_Log;
