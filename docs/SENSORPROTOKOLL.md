# Stasjonær sensorvalidering

Motorstrømmen skal være frakoblet; USB og sensorforsyning beholdes. Diagnostikkprosjektet sender stopp og sentrerer servoen til tidligere mekanisk verifiserte 84°. Det kaller aldri `Drive`. Etter fullført forsøk blir det stående i stopp. Ikke bruk `tools/mb.py flash` til denne testen: den kommandoen velger det autonome hovedprogrammet.

## Koblinger som må bekreftes fysisk

| Sensor | TRIG | ECHO |
|---|---|---|
| Front | P13 | P1 |
| Venstre | P14 | P2 |
| Høyre | P15 | P8 |

Felles GND kreves. Bruker oppgir 1 kΩ og 1,2 kΩ i hver ECHO-spenningsdeler. Rekkefølgen er ikke bekreftet. Beregnet ved 5 V: 1 kΩ mellom ECHO og signal, 1,2 kΩ mellom signal og GND gir 2,73 V; motsatt gir 2,27 V. Micro:bits dokumenterte minimum for høyt signal er 0,7 VDD, tilsvarende 2,31 V ved antatt VDD=3,3 V. Dette er en betinget beregning, ikke en måling av kortet. Mål faktisk forsyning og signalnivå; et multimeter viser ikke sikkert pulstoppene.

Et eldre diagram fra chatten «Koble opp adaptive lys servo ultrasonic» gjaldt én sensor, tre 10 kΩ-motstander og LED på blant annet P2/P14. Det beviser ikke dagens koblinger. Kontroller at ingen gammel LED-last deler venstre ECHO/TRIG. Ikke flytt ledninger mens forsyningen er på.

## Bygg og innsamling

Python 3, PySerial og pyOCD kreves for fysisk innsamling; native GNAT kreves for Ada-vertstestene. Rene Python-analysetester bruker standardbiblioteket. Disse verktøyene var tilgjengelige i denne økten; kjør ikke en antatt vellykket test uten å kontrollere exitstatus og logg.

Bruk repoets Alire-verktøykjede via `python tools/build_sensor_diagnostic.py`. Dette tilsvarer `alr exec -- gprbuild -p -P Code/diagnostics/sensor_diagnostic.gpr --root-dir=. --relocate-build-tree=build/sensor-diagnostic`, og støtter også repoets lokalt administrerte Alire-installasjon.

```text
python tools/sensor_experiment.py --flash --output docs/evidence/NYTT-FORSOK --context "Faktisk oppsett, referanseavstander og endringer"
python tools/analyze_sensors.py docs/evidence/NYTT-FORSOK/samples.csv --output docs/evidence/NYTT-FORSOK/analysis.json
python tools/test_navigation.py
python -m unittest discover -s tests -p test_sensor_analysis.py -v
```

Resultatmappen må være ny. Innsamlingen er tidsbegrenset og lagrer også feil, firmwarehash og delvise data. En fullført serie skal ha nøyaktig 320 sammenhengende sekvensnumre og avslutningsmeldingen `DONE,320,MOTION_DISABLED`. CSV-importen avviser manglende/repetert sekvens, negative tall, ukjente feilkoder og gyldigmerket avstand utenfor 2–200 cm. Innsamlingsstatus må kontrolleres separat; en delvis CSV kan analyseres, men er ikke et fullført forsøk.

Hver serie inneholder 40 runder front–venstre–høyre med 65 ms globalt triggerintervall, deretter 40 runder med 100 ms, deretter 40 målinger venstre alene med hvert intervall. Dette er 80 front-, 160 venstre- og 80 høyremålinger. Intervallfeltet beskriver planlagt tid til neste trigger; fasens første faktiske gap kan komme fra forrige fase. Analyse av minste gap utelater faseovergangen. Faseorden er fast: forskjeller kan også skyldes tid eller endret målescene. Gjenta med stabilt oppsett før årsaksslutninger.

## Kjente avstander og filterforsøk

1. Bruk en stor, flat målflate vinkelrett på sensoren, uten hjul/chassis i strålen. Mål fra sensorens front. Registrer plassering, målflatens størrelse, strømoppsett og om andre sensorer er tilkoblet.
2. Start med 60 cm på venstre. Gjenta deretter ved 20, 30, 45, 100 og 150 cm når praktisk mulig. Registrer hver serie i en egen mappe, minst tre repetisjoner per oppsett.
3. Oppgi bare faktisk målte referanser. Eksempel på JSON for en serie der **venstre faktisk står 60 cm fra målflaten**: `{"ALL_65/L":60,"ALL_100/L":60,"LEFT_65/L":60,"LEFT_100/L":60}`. Bruk `--references referanser.json` ved analysen. Ingen fil med antatte måleavstander er levert som eksperimentresultat.
4. Rapportér antall gyldige, feilkoder, ugyldigandel, gjennomsnitt, median og utvalgsstandardavvik. Med kjent referanse beregnes bias, MAE og RMSE. Manglende referanse gir `null` for feilmetrikker. Spredning alene viser ikke nøyaktighet.
5. Sammenlign median og konsistent minimum på ikke-overlappende tripler. Begge avviser hele trippelen ved ugyldig ekko. Minimumskandidaten krever også spenn ≤15 cm og beholder den nærmeste hindringen. Dette er analysekandidater; de erstatter ikke automatisk den aktive Ada-filtreringen. Logg forkastede tripler og ubrukte restmålinger.

## Isoler feilen med én endring om gangen

- Sammenlign bounded ventetid før ECHO-stigning. V1 bruker 3 ms; V2 10 ms. Ingen av disse er målte maksimumsgrenser for alle HC-SR04-varianter.
- Med all strøm av: verifiser spenningsdeler, felles GND, kontakt og eventuelle delte LED-pinner. Registrer faktisk funn før endring.
- Hvis feilen består, bytt bare venstre og høyre sensormodul ved modulenes kontakter, med strømmen av. Behold de respektive mikrokontrollerpinnene og spenningsdelerne. Identifiser modulene fysisk og logg hva som ble flyttet. Feil som følger modulen, og feil som blir på kanalen, gir ulike hypoteser; ett bytte alene beviser ikke årsaken.
- Undersøk refleksjon/monteringsvinkel og kortere ledninger, deretter støy under servo-/motorbelastning. Belastningstester krever eget sikret oppsett og ny protokoll. Ingen slike tester er utført i den første serien.

## Godkjennings- og stoppkriterier

Før nye gulv-/svingtester må alle nødvendige sensorretninger gi tilstrekkelig stabile målinger i det aktuelle området. Null er ukjent avstand, aldri fri vei. Et godt resultat ved én statisk målflate garanterer ikke refleksjon fra skrå eller myke hindringer. Ingen rygging uten verifisert bakområde. Behold konservative navigasjonsgrenser til fart, reaksjonstid og retardasjon er målt.

Maksimal observert lesetid er ikke WCET. Ada-runtimeklokken bruker RTC med omtrent 30,5 µs oppløsning, og polling/avbrudd gir ytterligere tidsusikkerhet. `pulse_us / 58` er en nominell databladmodell. Den opprinnelige løkketelleren bygger på en håndjustert forsinkelse og er ikke en kalibrert tidsmåling. Oscilloskop/logic analyzer og kjente avstander er nødvendig for videre tids-/avstandskalibrering.

Kilder: [HC-SR04-datablad](https://cdn.sparkfun.com/datasheets/Sensors/Proximity/HCSR04.pdf), [micro:bit edge connector](https://tech.microbit.org/hardware/edge-connector/), lokal runtime `gnarl/s-bbbosu.adb` og `MicroBit.TimeHighspeed`. Relevante teorikoblinger i `ISforelesninger.pdf`: PDF-side 20 om responstid og 74 om fail-safe.
