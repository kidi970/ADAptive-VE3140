# ADAptive – komplett koblingsplan

Samlepakke oppdatert 11. november 2026 mot siste kildekode fra 4. november
i `src/` (eller `Code/src/` i kildekode-ZIP-en). Motorplasseringen i PDF-en er rettet til samme kart
som denne pinneplanen og siste motorkode. Ingen ny fysisk kontroll er utført.

Den utskriftsvennlige planen genereres med
`python3 docs/wiring/render_guide.py` i originalprosjektet. Den ferdige
`ADAptive-komplett-koblingsplan.pdf` følger denne leveransen.
Den har seks sider med oversikt, påskrifter, breadboardtegning, sensorer,
lys og øvrige forbindelser. Originalplanen var visuelt kontrollert side for side; samlepakken retter motormerkingen på side 1 og 6.
Hullene fra den tidligere 5,1 kΩ / 6,8 kΩ-planen er bevart.

## Fast pinneplan

| Funksjon | Tilkobling |
|---|---|
| Frontsensor | TRIG P13, ECHO via deler til P1 |
| Venstre sensor | TRIG P14, ECHO via deler til P2 |
| Høyre sensor | TRIG P15, ECHO via deler til P8 |
| To røde baklys | P0, hver LED gjennom egen 1 kΩ |
| Blinklys venstre / høyre | P12 / P16, hver gjennom egen 1 kΩ |
| Frontservo | S2, signal / VIN / GND |
| OLED | SCK til P19/SCL, SDA til P20/SDA |
| Motorkart | M1 bak H, M2 foran H, M3 bak V, M4 foran V |
| Raspberry Pi | USB-A til micro:bit micro-USB, ingen Pi-GPIO |

## Hullplassering

Brettet holdes med a–e til venstre, f–j til høyre og rad 1 øverst.
Kontaktgruppene a–e og f–j på samme rad er elektrisk adskilt.

| Sensor | ECHO inn | 5,1 kΩ | 6,8 kΩ | Utgang | Jordjumper |
|---|---|---|---|---|---|
| Front | a2 | e2–f2 | h2–h5 | j2 til P1 | j5 til GND |
| Venstre | a7 | e7–f7 | h7–h10 | j7 til P2 | j10 til GND |
| Høyre | a12 | e12–f12 | h12–h15 | j12 til P8 | j15 til GND |

Hver sensors VCC går til regulert 5 V, GND til felles GND og TRIG til
signalpinnen i tabellen. Nominelt 5 V ECHO gir 2,857 V etter deleren.
Dette er beregnet, ikke målt. ECHO må ikke mates til en strømløs micro:bit.

| LED | Signal inn | 1 kΩ | Anode | Katode | Jordjumper |
|---|---|---|---|---|---|
| Bak venstre | P0 til a18 | e18–f18 | h18 | h19 | j19 til GND |
| Bak høyre | b18–b21 jumper | e21–f21 | h21 | h22 | j22 til GND |
| Blink venstre | P12 til a24 | e24–f24 | h24 | h25 | j25 til GND |
| Blink høyre | P16 til a27 | e27–f27 | h27 | h28 | j28 til GND |

## Presiseringer fra kildekontrollen

- GPIO-feltets signal er kolonnen **P**, med **3V3** og **GND** ved siden av.
  Servofeltet bruker **S**, **VIN** og **GND**. S2 og P2 er forskjellige.
- OLED-bildet viser **1 GND, 2 VIN, 3 SCK, 4 SDA**. Tidligere guide omtalte
  strømterminalen som VDD. Det er rettet til bildets VIN i denne planen.
- DFR0548 V2.0-skjemaet kobler M1 til PCA9685-kanalene 6/7, M2 til 4/5,
  M3 til 2/3 og M4 til 0/1. Hovedprogrammets bufferrekkefølge er derfor
  M4, M3, M2, M1. Brukeren observerte på benken at dette er venstre foran,
  venstre bak, høyre foran og høyre bak. Rotasjonsretning ble ikke rapportert.
- Med en egnet regulert ekstern 5 V-forsyning til driverkortets +/−-inngang
  kan ledig S1 VIN forsyne venstre røde sensorskinne. S1 GND går til
  venstre blå skinne, som forbindes med høyre blå. S1-signal brukes ikke.
  VIN er ikke en uavhengig regulert 5 V-utgang og forsyner også motorstyringen.
- Høyre røde skinne reserveres til 3V3. Røde skinner skal ikke forbindes.
  Skinnene kan være internt delte; sammenheng er ikke målt her.
- OLED kobles til IIC G/V/C/D (GND/3V3/SCL/SDA) bare når modulens
  3,3 V-kompatibilitet og pull-ups er avklart. Inntil da skal både buss og
  strøm til skjermen være frakoblet. VIN-etiketten fastslår ikke tillatt spenning.
- Motorpolaritet, hjulorientering, faktisk forsyning, motstandsverdier og
  fysisk virkemåte står som **ikke testet**.
- `standalone_components.adb` har egen komponenttestpinneplan og skal
  ikke brukes som koblingsfasit for bilen.

## P8 og firmware

Siste firmware krever at P8 er konfigurert som GPIO i UICR. HEX-filen
endrer ikke denne innstillingen; ved aktiv NFC stopper oppstarten med
`P8 NFC mode blocks right echo`. Programmet sjekker denne innstillingen i `src/adaptive_sensors.adb`.

## Kilder

- [DFRobot DFR0548, V2.0-skjema](https://wiki.dfrobot.com/dfr0548/docs/18216)
- [micro:bit pinnefunksjoner og elektriske grenser](https://tech.microbit.org/hardware/edge-connector/)
- [HC-SR04, ELECFREAKS-datablad](https://cdn.sparkfun.com/datasheets/Sensors/Proximity/HCSR04.pdf)
- `src/adaptive_sensors.adb`, `adaptive_lights.adb`, `adaptive_motion.adb`
  og `adaptive_display.adb`, samt brukerens bilder og tidligere pinneplan.
