# ADAptive – Utviklings- og testlogg
Dato: 21.10.2026
Prosjekt: VE3140 – Intelligente sanntidssystemer

## 1. Sammendrag
ADAptive er videreutviklet med autonom styring basert på en tilstandsmaskin (FSM), servobasert ultralydskanning, motorstyring og visuell retningsindikasjon på micro:bit V2.

Siste bekreftede resultat er en vellykket bygging og fysisk test av LED-retningsvisningen.

## 2. Programmering og funksjonalitet
- FSM med tilstandene Stop, Forward, Reverse_Drive, Scan, Turn og Verify.
- HC-SR04 brukes til å måle avstand i flere retninger via SG90-servo.
- Retningsvalget prioriterer fri vei fremover, deretter høyre og venstre.
- Motorstyring utføres gjennom MicroBit.MotorDriver.
- 5×5 LED-matrisen viser valgt retning: fremover, høyre, venstre eller blokkert.
- LED-indikasjonen følger FSM-ens beslutning, ikke nødvendigvis retningen med størst målt avstand.

## 3. Problemer og løsninger
### LED-driver
Problem: Kompilatoren fant ikke MicroBit.Display.

Årsak: MicroBit.Display ligger i ZFP-delen av Ada_Drivers_Library og er ikke inkludert i prosjektets eksisterende full-konfigurasjon.

Løsning: Bruke MicroBit.DisplayRT, som allerede er tilgjengelig gjennom microbit_v2_full.gpr.

Resultat: Programmet kompilerer, og LED-retningsvisningen fungerer på fysisk micro:bit V2.

### I2C og ultralyd
Det finnes lokale endringer i:
- boards/MicroBit_v2/src/full/microbit-i2c.adb
- boards/MicroBit_v2/src/full/microbit-ultrasonic.adb

Endringene er lagret i en separat Git-patch. Patchen er validert med git apply --check --reverse.

## 4. Tester og resultater
| Test | Resultat |
|---|---|
| Ada-kompilering | Bestått |
| Linking | Bestått |
| Generering av main.hex | Bestått |
| Flashing til micro:bit V2 | Bestått |
| LED-retningsvisning på fysisk enhet | Fungerer, bekreftet av utvikler |
| Full autonom gulvkjøring med selvstendig strømforsyning | Ikke ferdig verifisert |

Siste bygg:
- Flash: 191324 byte (36,49 %)
- RAM: 15600 byte (11,90 %)
- Byggetid: 2,04 sekunder
- Fire eksisterende kompilatoradvarsler knyttet til ultralydimplementasjonen.

## 5. Tidligere testobservasjoner
Tidligere benketester har vist:
- Stopp ved hindringer.
- Servobasert skanning og valg av kjøreretning.
- Motorrespons og høyresving.
- Behov for videre testing av stabil strømforsyning og kontinuerlig autonom drift.

Disse observasjonene stammer fra tidligere utviklingsøkter og er ikke alle gjentatt 21.10.2026.

## 6. Prosjektstatus
Bekreftet:
- Prosjektet bygger.
- Firmware kan flashes.
- LED-indikasjonen fungerer.
- FSM, sensorer og motorstyring er integrert i kildekoden.

Gjenstår:
- Verifisere stabil strømforsyning uten USB.
- Teste komplett autonom kjøring på gulv.
- Kontrollere stopplengde, sidekollisjoner og nødstoppsituasjoner.
- Gjennomføre og dokumentere systematiske tester av alle FSM-overganger.
- Gjennomgå eksisterende ultralydadvarsler.

## 7. Neste steg
1. Sikre reproducerbar bygging fra GitHub, inkludert drivertilpasningene.
2. Teste strømforsyning og motorer med hjulene løftet.
3. Gjennomføre kontrollerte autonome kjøretester.
4. Samle måledata og observasjoner til VE3140-prosjektrapporten.

## 8. Reproduserbarhet
Prosjektet bruker Ada_Drivers_Library som Git-undermodul.

Lokale drivertilpasninger finnes i:
patches/ada-drivers-2026-10-21-raw.patch

Patchen må vurderes og anvendes ved ny kloning dersom byggingen avhenger av disse tilpasningene.
