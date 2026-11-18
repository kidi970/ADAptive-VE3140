# Oppkobling for gulvversjonen

| Del | Tilkobling |
|---|---|
| HC-SR04 foran | TRIG P13, ECHO via spenningsdeler til P1 |
| HC-SR04 venstre | TRIG P14, ECHO via spenningsdeler til P2 |
| HC-SR04 høyre | TRIG P15, ECHO via spenningsdeler til P8 |
| Frontservo | S2 |
| OLED | P19 SCL, P20 SDA |
| Bremselys | P0 |
| Venstre og høyre blinklys | P12 og P16 |
| Lyd | Innebygd høyttaler på micro:bit V2 |

Spenningsdeleren for hver ECHO bruker 5,1 kΩ fra ECHO til målepunktet og 6,8 kΩ fra målepunktet til felles GND. Hver LED bruker en egen 1 kΩ seriemotstand.

Den testede bilen har felles jord mellom motorkortet og de blå breadboardskinnene. Sensorenes 5 V-skinne og 3,3 V-skinnen bruker hver sin røde skinne. Kjøringen på powerbank ble gjennomført med en VARTA Energy 57976 og en polarisert 1000 µF / 16 V kondensator på sensorforsyningen, med pluss til 5 V og minus til jord.

## P8 for høyre sensor

P8 må være konfigurert som GPIO på micro:bit V2. På et nytt eller fullstendig slettet kort må `UICR.NFCPINS.PROTECT` (`0x1000120C`, bit 0) settes til `0` for GPIO. Start kortet på nytt etter konfigureringen. HEX-filen inneholder programflashen, og denne kortinnstillingen lagres separat i UICR.

## Motorstyring

Motorportene på den testede bilen er M1 bak venstre, M2 foran venstre, M3 bak høyre og M4 foran høyre. «Frem» og «revers» angir programkommandoene per port.

| Bevegelse | M1 | M2 | M3 | M4 |
|---|---|---|---|---|
| Rett frem | Frem | Frem | Frem | Frem |
| Sving høyre | Revers | Revers | Frem | Frem |
| Sving venstre | Frem | Frem | Revers | Revers |
