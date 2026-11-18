# ADAptive – gulvversjon 18. november 2026

Denne firmwaren kjører på ADAptive-bilen med micro:bit V2, DFR0548 V2.0, fire Mecanum-hjul, tre HC-SR04, frontservo, OLED og lys.

- [ADAptive-siste.hex](ADAptive-siste.hex) kan flashes til micro:bit V2.
- [ADAptive-kildekode.zip](ADAptive-kildekode.zip) inneholder byggeprosjektet, driverne og Ada-testene.
- [src/](src/) viser Ada-koden fra byggepakken.
- [Oppkobling](PINNEPLAN.md), [programvaretester](programvaretester.txt) og [SHA256SUMS](SHA256SUMS).

## Kjøring

1. Slå på bilstrømmen og vent til OLED viser `STATUS: STOP` eller serieloggen viser `READY`.
2. Trykk **A** for å starte. **B** stopper motorene og låser stopp til reset.
3. OLED viser kjørestaten. Ved blokkert fremdrift kan den øverste linjen vise målingen som sperrer. Serieloggen bruker 115200 baud.

Bilen kjører rett frem når fronten og hjørnene har klaring. Under kjøring leses begge sidesensorene i hver runde. Programmet følger med på sidegap innenfor 30 cm og søker en sving bort fra siden når gapet minker. Når målt sidegap er 11 cm eller mindre, venter svingplanleggeren med motorene av og servosensoren sentrert.

En egen regel for rett passering bruker minst 9 cm målt sidegap og sjekker fronten og begge hjørnene før bevegelse. En fullført `OPEN`-puls kan under disse vilkårene gi ett kort steg med ny sjekk ved stillstand. Ugyldige målinger sperrer bevegelse. Bremselys, blinklys og innebygd lydvarsel er aktivert.

## Flash og bygg

Koble fra motorstrømmen før du flasher micro:bit V2. Bruk den nedlastede HEX-filen. For å bygge firmwaren fra kilden, pakk ut byggepakken og kjør følgende fra den utpakkede mappen.

```sh
python3 tools/mb.py build
python3 tools/test_navigation.py
```

Bygget lager `build/main.hex`, `build/main.elf` og `build/main.bin`. Pakken ble bygd med Alire 2.1.1, GNAT ARM ELF 15.1.2 og gprbuild 25.0.1. Native Ada-tester krever `gnatmake`. På en ny maskin kan `python3 tools/mb.py setup` brukes til verktøyoppsettet.

Byggepakken inkluderer Ada Drivers Library fra `8e90f85575666684cc6e0b51830494de259bd3bc` med de tre driverendringene som ble brukt på bilen. ZIP-en inneholder også driverrettingene som en patch. Se pinneplanen for GPIO-innstillingen som kreves for P8.

## Verifisering

Programsegmentene ble lest tilbake fra micro:bit-kortet 18. november og samsvarte med den installerte ELF-filen. Avlesningen bekreftet samme UICR-innstillinger før og etter flashing. Kjøring på gulv med powerbank ble bekreftet etter siste oppdatering.

Et separat ARM-bygg fra den utpakkede ZIP-filen produserte en HEX-fil med identisk SHA-256. Alle 18 Ada-testsuitene besto med 11 046 kontroller, inkludert 122 navigasjonskontroller med simulerte sensorer og motorbuss.

Kjør `sha256sum -c SHA256SUMS` i leveransemappen for å kontrollere filene.
