# ADAptive – stasjonær sensorøkt 23.10.2026

## Utgangspunkt og bevaring

Arbeidsgren `fix/startup-navigation-2026-10-23`, utgangspunkt `02b542fdf68a4cb1e9b7394d3290a47beeb5b436`. Branch, status og diff ble kontrollert før endring. Eksisterende `.vscode/launch.json`, lokale driverendringer og eldre uversjonerte arbeidskopier beholdes. Sikkerhetskopi av lokal tilstand og faktisk Overleaf-kildeeksport ligger utenfor repoet i `backups/sensor-session-2026-10-23/` i arbeidsområdet. Ingen reset, rebase, merge til main eller force-push.

Det gjenfunne koblingsdiagrammet fra «Koble opp adaptive lys servo ultrasonic» gjaldt ett HC-SR04 og tre 10 kΩ-motstander. Det bekrefter ikke dagens tre sensorer med 1 kΩ/1,2 kΩ. Diagrammets LED på P2/P14 ga et kontrollpunkt. Etter forsøkene bekreftet bruker 23.10.2026: «Ja, bare venstre ultralydsensor bruker P2/P14». Hypotesen om delt LED-last legges dermed til side på grunnlag av brukeropplysningen. Motstandsorienteringen er fortsatt uavklart.

## Implementert

- `Adaptive_Range_Model`: ren Ada-modell for puls/58, arbeidsområde 2–200 cm og betinget spenningsdelerberegning med inputvalidering.
- `Adaptive_Echo`: separat diagnostisk GPIO-avlesning med status for manglende stigning, manglende fall, allerede høyt ECHO og avstand utenfor området. Logger faktisk klokkepuls parallelt med eldre løkketeller. Endelig diagnostikk bruker 10 ms stigningsfrist og 23 ms fallfrist. Dette er ikke endret i det aktive navigasjonsbiblioteket.
- `Code/diagnostics/sensor_diagnostic.gpr` og `.adb`: separat ARM-bilde, 16 KB primærstakk, fire stasjonære forsøksfaser og 320 avlesninger. Initialiserer stopp, sentrerer servoen til 84°, sender stopp etter forsøket og venter. Ingen `Drive`-kall.
- `tools/build_sensor_diagnostic.py`: bygger via repoets Alire-oppsett og bevarer `build/main.elf`.
- `tools/sensor_experiment.py`: eksplisitt flashing bare av diagnostikkbildet, ny resultatmappe, COM5-innsamling med tidsgrense, rålogg/CSV/firmwarehash og feilbevaring.
- `tools/analyze_sensors.py`: streng CSV-validering, feilkodetelling, ugyldigandel, gjennomsnitt, median, utvalgsstandardavvik og referanseavhengig bias/MAE/RMSE. Median og konsistent minimum sammenlignes på ikke-overlappende tripler med ugyldighetsveto. Ingen kandidat er automatisk satt inn i navigasjonen.
- 24 nye native Ada-kontroller og 16 Python-enhetstester. Eksisterende 1729 Ada-kontroller beholdes.
- Sensorprotokoll og datert rapportdel, med rådata for begge serier i den eksisterende Overleaf-rapporten.

## Fysiske forsøk

Bruker bekreftet frakoblet motorstrøm, tilkoblet USB og strømforsynte sensorer. Ingen belastnings-, hjul-, sving- eller gulvtester ble utført. Sensorenes faktiske målflater/avstander er ikke oppmålt i disse seriene. Begge diagnostikkseriene fullførte og sendte avsluttende stopp.

| Serie/fase | F gyldige | L gyldige | R gyldige | Venstre feil |
|---|---:|---:|---:|---|
| 1: alle 65 ms |40/40|16/40|40/40|24 NO_RISE|
| 1: alle 100 ms|40/40|10/40|40/40|30 NO_RISE|
| 1: venstre 65 ms|–|5/40|–|35 NO_RISE|
| 1: venstre 100 ms|–|5/40|–|35 NO_RISE|
| 2: alle 65 ms|40/40|29/40|40/40|11 NO_RISE|
| 2: alle 100 ms|40/40|28/40|40/40|11 NO_RISE, 1 utenfor område|
| 2: venstre 65 ms|–|30/40|–|10 NO_RISE|
| 2: venstre 100 ms|–|28/40|–|12 NO_RISE|

Serie 1: 320 avlesninger med 3 ms stigningsfrist. Venstre ugyldigandel 124/160 = 77,5 %. Front og høyre gyldige 80/80 hver. Gyldige venstreekko kom ofte nær fristen; tidsdifferansen lesetid minus pulstid lå rundt 2,6 ms i median. Dette motiverte en separat timeout-hypotese.

Serie 2: 320 avlesninger med 10 ms stigningsfrist, ellers samme programsekvens. Venstre ugyldigandel 45/160 = 28,125 %, inkludert én måling utenfor området. Front og høyre gyldige 80/80 hver. Større ventetid ga flere mottatte ekko, men venstres avstandsspredning økte til omtrent 23–26 cm standardavvik per fase. Dette er ikke tilstrekkelig dokumentasjon på stabil eller korrekt avstand.

Maksimal observert avlesningstid: 7935 µs i serie 1 og 10071 µs i serie 2. Fast faserekkefølge, scene som ikke er uavhengig kontrollert og ukjente referanseavstander begrenser sammenligningen. Ingen MAE/RMSE er rapportert for de fysiske dataene. Klokkebaserte avstander ligger over den eldre løkketelleren, men nøyaktigheten er ikke fastslått. Det er ikke påvist at krysstale, elektrisk nivå eller sensorvariant er årsaken.

**Konklusjon:** P0 er fortsatt åpent. Lengre pause og isolert venstremåling fjernet ikke feilen. 10 ms alene er ikke tatt inn som navigasjonsretting. Ugyldig betyr fortsatt ukjent og skal gi stopp når målingen er nødvendig. Micro:biten står igjen med stasjonær diagnostikk V2, ikke autonomt hovedprogram.

## Matematikk og sanntid

Nominalmodellen er `d_cm = pulse_us/58`. Runtime-kilden bruker RTC ved 32768 Hz: ca. 30,5 µs tidskvantisering, tilsvarende ca. 0,526 cm før polling/avrunding/avbrudd. Dette er ikke målt avstandsnøyaktighet. `Delay_Us` er en håndjustert NOP-løkke og kan ikke brukes som bevis på nøyaktig mikrosekundtid.

Spenningsdeling: `V_signal = V_echo * R_gnd/(R_series+R_gnd)`. Ved 5 V gir 1 kΩ serie og 1,2 kΩ til jord 2,727 V; reversert 2,273 V. Ved antatt VDD=3,3 V er dokumentert minste høynivå 0,7 VDD = 2,31 V. Orientering og forsyningsnivå må fortsatt måles/bekreftes. Dette er en hypotese, ikke en fastslått feil.

Analyseverktøyet bruker bias = middelavvik, MAE = middel absoluttavvik og RMSE = roten av middel kvadratavvik mot en eksplisitt referanse. Uten referanse gir det `null`; gyldig spredning og ugyldigandel rapporteres separat.

`ISforelesninger.pdf` (336 sider) ble kontrollert på PDF-side 20 (responstid) og 74 (fail-safe). Målt sensorrutinetid dekker ikke hele inngang-til-stopp-kjeden og er ikke bevist WCET. Ingen fart, retardasjon, bremselengde, PID, odometri eller IMU-ytelse er målt i denne økten.

## Bygg og automatiserte kontroller

- `python tools/test_navigation.py`: PASS 1729 eksisterende + 24 nye Ada-kontroller = 1753.
- `python -m unittest discover -s tests -p test_sensor_analysis.py -v`: 16/16 Python-enhetstester.
- Diagnostikk V2: bygget og flashet; linker 215708 B flash og 28888 B SRAM, inkludert reserverte stakker. Dette er linkerforbruk, ikke dynamisk toppforbruk.
- `python tools/mb.py build`: navigasjonsfirmware bygget/oppdatert uten kildeendring; ikke flashet etter sensortesten.
- Begge innsamlinger: exit 0, 320 rader og sluttmelding. Rådata, kildeøyeblikksbilder og firmware-SHA finnes i `docs/evidence/2026-10-23-sensors/run-01/` og `run-02/`.
- Syntetiske tester validerer analyse og rene modeller. De beviser ikke at GPIO-avlesningens alle feilforløp er fysisk testet.

## Rapport, versjonskontroll og videre arbeid

Eksisterende rapport beholdes. Nytt avsnitt 7.6 beskriver oppsett, elektriske hypoteser, modeller, forsøkssekvens, resultater, filtrering, sanntidsbegrensninger og neste forsøk. Sammendraget viser til studien; historisk tekst og tidligere kode beholdes. Faktisk Overleaf-kompilering ga 45 sider, 0 feil, 0 ordinære advarsler, 2 underfull-meldinger i bevart tekst/bibliografi og ingen overfull-meldinger. PDF-side 22–24 er visuelt kontrollert; alle sider er sett i oversikt, alle 23 skrifter er innebygd og tekstuttrekket har ingen `??`-henvisninger. PDF-hash og begrensninger står i `VALIDERING.md`. Kildeeksportens integritet kontrolleres separat ved avsluttende pakking.

Endringene skal committes på den eksisterende arbeidsgrenen og pushes uten force når autentisering tillater det. Faktisk SHA/pushstatus rapporteres etter utført commit/push; denne loggen påstår ikke et forhåndsresultat.

Neste steg er oppmålt venstremålflate ved 60 cm og fysisk kontroll av motstandsrekkefølge og GND. Deretter kontrollert modulbytte med strøm av, gjentatte serier ved kjente avstander og én endring om gangen. Først etter stabil nødvendig sensordekning fortsetter løftede høyre-/venstresvinger, gulvkjøring og bremselengdemåling. Protokollen gir nøyaktige trinn.

## Oppfølging: bekreftet pinnebruk

Fra revisjon `10227bc` er dokumentasjonen presisert med brukerens bekreftelse om P2/P14. Ingen firmwarekode, terskler eller måledata er endret, og ingen nye fysiske forsøk eller programtester er kjørt i denne dokumentasjonsoppfølgingen. Tidligere bygg- og testresultater gjelder fortsatt den samme koden. Rapporten er kompilert på nytt i det eksisterende Overleaf-prosjektet: 45 sider, 0 feil, 0 ordinære advarsler og to eksisterende underfull-meldinger. Endret tekst er visuelt kontrollert; ny PDF-hash og avgrensninger er registrert i `VALIDERING.md`. Nye referansemålinger og motstandsrekkefølge avventer fortsatt fysisk avklaring.
