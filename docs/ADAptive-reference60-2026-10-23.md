# ADAptive – referansetest 60 cm, 23.10.2026

## Resultat og sikkerhetsgrense

Venstre var repeterbar ved den oppgitte 60 cm-målflaten: tre nye GPIO-serier, hver med 160 gyldige venstremålinger, totalt 480/480 og ingen feilkoder eller timeouts. Dette lukker ikke P0. Avstandsestimatet ligger systematisk lavt, elektrisk signalmargin er ikke målt, og full diagnostikk med I2C/motorstyring feiler ved oppstart. Ingen hjul-, sving-, servogrense- eller gulvtest ble utført. Motorstrømmen er fortsatt frakoblet ifølge brukerens oppsett; agenten har ikke fysisk kontrollert forsyningen.

## Baseline og bevaring

Repo: C:\Users\jacob\ADAptive\ADAptive-VE3140. Gren: fix/startup-navigation-2026-10-23, HEAD ved start ed6cb03 (etter 10227bc). Status, diff og staged diff ble kontrollert før endring. Eksisterende .vscode/launch.json, endret undermodul og uversjonerte filer ble bevart. Sikkerhetskopi av patcher, uversjonerte filer og lokal rapport ligger i arbeidsområdets backups/reference60-2026-10-23. Overleaf-kilden ble eksportert før endring; main.tex og sensorstudien var byteidentiske med lokal rapportkopi.

Forrige serie: venstre 45/160 ugyldige (28,125 %), 115 gyldige, ukjent referanseavstand; tidligere samlet 640 sensormålinger. De gamle målingene skal fortsatt ha null for MAE/RMSE. Ny målscene og V3 uten I2C betyr at endringen til 0 % ugyldige ikke identifiserer årsak eller en isolert forbedring av én variabel.

## Oppsett og faktisk tilgang

Bruker hadde allerede rigget flat pappflate vinkelrett foran venstre ved oppmålt 60 cm, uten LED/annen last på P2/P14, og motorstrøm frakoblet. Oppsettet ble brukt uten nye forespørsler om rigging. Protokollens avstandsdatum er sensorens front. 60 cm er brukeroppgitt referanse; agenten har ikke sett målebånd, datum, flatens mål eller måleusikkerhet. Tallene under er derfor feil mot oppgitt referanse, ikke sporbar kalibrering.

COM5 ble identifisert som USB VID_0D28 PID_0204 MI_01. Innstillinger: 115200 baud, 8 databiter, ingen paritet, 1 stoppbit, ingen programvare-/maskinvareflytkontroll. CMSIS-DAP-probe: 9906360200052820642034ba85c73f41000000006e052820. Kildens UART-konfigurasjon stemmer med innsamlingen.

Opprinnelig flash ble sammenlignet byte for byte med V2 ELF i to lastesegmenter; SHA256 for ELF: 2fcfc092ae4df89342d52df26a55172997d99eec876a534e5dd9ab3731c5def5. Første bulklesing fikk debugger-timeout. CMSIS-DAP v1, én pakke om gangen, uten deferred transfers og 256-byte leseblokker fullførte verifiseringen. Debuggerens første tilkobling haltet CPU; dette er ikke bevis på tilstanden før tilkobling.

## Feil og neste implementerte utvikling

run-01: omstart av verifisert V2 ga banner og DIAGNOSTIC FAULT PROGRAM_ERROR før første måling. Ingen data er fabrikert. Feilen kom umiddelbart, før OLED-initens 0,5 s pause. Dette samsvarer med eksplisitt Program_Error ved mislykket motor-I2C-overføring i Adaptive_Motion.Initialize/Write. Eksakt I2C-status og fysisk årsak er ikke målt. Brudd/strøm/ACK må undersøkes senere; motorstrøm ble ikke koblet til.

Ny separat sensor_gpio_diagnostic.gpr/.adb (V3) bevarer samme Echo.Read og fire faser som V2, men importerer ikke motor-, OLED- eller I2C-modulene og skriver ikke servo. Den har ingen Drive/Stop-kall og påstår ikke at et elektrisk motorstopp er bekreftet. Fysisk frakoblet motorstrøm er forutsetningen. Banner: NO_MOTOR_WRITES; slutt: DONE,320,NO_MOTOR_WRITES. V2 og navigasjonen beholdes uendret. Linket V3-bilde ble kontrollert uten motor-/display-/MicroBit.I2C-symboler.

Innsamleren støtter eksplisitt --gpio-only, --reset og --flash; reset krever at flash matcher valgt diagnosebilde. Den registrerer oppgitt motorfrakobling, probe-ID, faktiske serieinnstillinger, flashsegment-hasher, rålogg, relativt firmwaretidspunkt og UTC-mottakstider per USB-blokk. Fullført krever riktig banner, 320 sammenhengende sekvensnumre, riktig fase-/sensorrekkefølge og sluttmarkør uten feil. Lokal ELF-hash alene regnes ikke som firmwareverifisering.

Analysen gir nå også samlet statistikk per sensor og eksplisitt n for avstandsmetrikker. Ugyldige ekskluderes fra avstand, men teller i feilandel. Faser kan bare dele referanse i samlede feilmetrikker når alle har samme eksplisitte referanse. Manglende/ulike referanser gir null.

## Faktiske resultater

Hver fullførte serie har 320 avlesninger: 80 front, 160 venstre og 80 høyre. Alle 960 nye avlesninger var VALID_ECHO. Totalt med tidligere to serier: 1600 fysiske avlesninger. I run-01 kom ingen målinger.

| Serie | Gyldige L | Ugyldig | Snitt cm | Median cm | s cm | Bias cm | MAE cm | RMSE cm |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| run-02 |160/160|0 %|57,1696|56,8280|0,4938|-2,8304|2,8304|2,8729|
| run-03 |160/160|0 %|57,3141|56,8280|0,5257|-2,6859|2,6859|2,7366|
| run-04 |160/160|0 %|56,8411|56,8280|0,1171|-3,1589|3,1589|3,1610|
| Samlet |480/480|0 %|57,1083|56,8280|0,4653|-2,8917|2,8917|2,9288|

Ugyldige er eksplisitt ekskludert fra middel/median/spredning/bias/MAE/RMSE; her finnes ingen ugyldige å ekskludere. Front/høyre har ingen oppmålt referanse og dermed ingen fysiske feilmetrikker. I første fullførte serie var venstre gyldig 40/40 i hver av ALL_65, ALL_100, LEFT_65 og LEFT_100. Gyldighet alene bekrefter ikke korrekt avstand.

V3 ELF SHA256: 3501ef0926f900f916362fa2e804e5d0fcd18227f8323c6cb602000b7b4db6d7. Flash ble verifisert før hver logget omstart; første V3-serie flashet, de to neste bare resatte. Rådata og kildeøyeblikksbilder ligger i docs/evidence/2026-10-23-reference60/run-01..04. UTC i capture.json og host-receive-times.json er PC-tid; t_us i CSV er relativ firmwareklokke. Mottakstiden er ikke et eksakt UTC-tidspunkt for hver puls.

## Sanntid, usikkerhet og hypoteser

Maksimal observert venstrelesetid var 5676 us. Dette er ikke WCET, komplett reaksjonstid eller stopplengde. Nominell 10 ms rise + 23 ms fall + trigger/polling/avbrudd/retur er bare en del av en mulig tidsgrense, ikke bevist totalgrense. RTC-kvantisering rundt 30,5 us og polling er uendret. Gyldig venstreavstand i seriene tok bare verdiene 56,828 og 57,879 cm, så mange desimaler i loggen betyr ikke tilsvarende oppløsning. Ingen automatisk +2,89 cm-korreksjon er innført fra ett målepunkt. Tre serier fra samme rigg er ikke uavhengige kalibreringer; null observerte feil er ikke garanti for null feilrisiko.

- ECHO P2: bruker bekrefter ingen delt LED-last. Motstandsorientering, toleranser, VDD og ECHO-høy/lav er fortsatt ikke fysisk målt. Fravær av LED beviser ikke trygt nivå.
- Betinget spenningsdeling ved 5 V: 1 kOhm serie/1,2 kOhm til GND gir 2,727 V; reversert 2,273 V. Sammenligning med 0,7*VDD krever faktisk VDD. Kilder: micro:bit edge connector og HC-SR04-datablad i rapportens bibliografi.
- TRIG P14/felles GND: kilde- og pinnetilordning kontrollert. Pulsamplitude/-bredde og fysisk kontinuitet ikke målt.
- Krysstale/tidsforskyvning: både alle-sensorfaser og venstre alene fullførte uten feil ved 65/100 ms global pause. Fast rekkefølge og tidsvariasjon begrenser årsaksslutning.
- Refleksjon/målflate: brukeroppgitt vinkelrett pappflate; størrelse og sensorens nøyaktige akse ikke uavhengig kontrollert.
- USB/I2C/strøm: USB-logg virker og GPIO-serier fullfører. V2s I2C-initfeil består som integrasjonsblokkering; det er ikke bevist at USB eller I2C var årsaken til gamle venstrebortfall.
- Sensorsvikt: modulbytte med all strøm av og sammenligning på samme kanal er ikke utført. Dataene alene avgjør ikke modulfeil versus kanal/krets/målemodell.

Neste nødvendige P0-arbeid er fysisk spennings-/jord-/TRIG-kontroll, avklaring av I2C-init uten å omgå stoppfeil, flere kjente avstander og kalibreringsanalyse. Etter stabil nødvendig sensordekning i full konfigurasjon følger hjul-løftet venstre/høyre-rotasjon, sving- og servokalibrering (34–134 grader må ikke åpnes automatisk), oppmålt chassis/sensorgeometri med usikkerhetsmargin, og først deretter kontrollert gulvtest. Fart, inngang-til-stopp-tid, retardasjon og stopplengde er ikke målt. Ingen PID/Kalman eller svekket fail-safe er innført.

## Tester og rapport

1753 Ada-kontroller (1729 policy/FSM + 24 range) og 29 Python-tester bestod. V2, V3 og navigasjonsfirmware bygget; navigasjonsbildet ble ikke flashet. V3s første bygg rapporterte 147 KiB flash og 27272 byte reservert SRAM. Vertstester er syntetiske og beviser ikke elektrisk sikkerhet.

Rapporten oppdateres i eksisterende Overleaf-prosjekt med dette oppsettet, faktiske CSV-/JSON-filer, feilen før datainnsamling, usikkerhet og åpen P0-port. Faktisk kompilering, PDF-QA og Git-resultat registreres separat når utført.


## Verifisert rapportavslutning

Overleaf ga 47 sider, 0 feil, 0 ordinære advarsler og to eksisterende underfull-meldinger etter siste TeX-endring. Faktisk PDF er lastet ned og visuelt kontrollert (hele dokumentet i oversikt, side 2/24/25/26/27 i full størrelse); alle skrifter er innebygd og ingen ??-henvisninger eller tomme sider ble funnet. PDF SHA256: 730b28bf7c58825b17f2fc99105518eb3ecec572efb2637df892ab5091fe5174. Implementasjonen er committet som 3bf373462d3a2715f2eded4aa83095c39481d1f5; endelig dokumentasjonscommit/push rapporteres ved øktslutt. Eksisterende lokale filer og diff er kontrollert bevart byte for byte. V3 står igjen uten motor-/servokommandoer og forutsetter fortsatt fysisk frakoblet motorstrøm. Ingen neste bevegelsesport er åpnet.
