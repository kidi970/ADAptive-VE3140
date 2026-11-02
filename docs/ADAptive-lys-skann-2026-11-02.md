# ADAptive – lys, adaptiv skanning og fysisk Pi-forbindelse

Oppfølging 2. november 2026, etter revisjon `6d95e17`. Samme arbeidsgren
`codex/pi-integration-exceptions-2026-11-02`. Brukeren bekreftet samme
maskinvare/pinner, fysisk isolert motorstrøm, sensorstrøm også av og fire
umonterte LED-er med fire 1 kΩ-motstander. Fremføring er oppgitt om omtrent
to–tre uker, eksamen om omtrent en måned. Datoene er ikke eksakt fastsatt her.

## Implementert

- **Lys:** P0 styrer to røde baklys med hver sin motstand; P12 og P16 styrer
  hvert sitt blinklys. Egen lavprioritets task med `delay until` og 50 ms
  myk oppdateringsperiode; blinkperioden er 1 s. Protected object deler
  status uten I2C/venting. Fault er sticky og worker-feil varsles til
  supervisoren. Ingen blinkeforsinkelse legges i navigasjonen.
- **Skanning:** generisk først-akseptabelt søk med 0–4 ekstra sideposisjoner,
  tidlig avvisning av ukjent/blokkert stråle og ny sentrert sensorkontroll.
  2000 ms aldersgrense; tidligere 5-/7-punktsrunder er erstattet i aktiv kode.
  0,5 s servo-ventetid og 65 ms triggeravstand beholdes. Skanning er fortsatt
  stasjonær. Dette er en eksplisitt heuristikk, ikke bevist global optimalitet.
- **Diagnostikk:** separat `lamp_diagnostic` uten motor-/servo-I2C, egen
  bygger og opptaker som validerer seriell modus mot faktiske GPIO-latcher.
  Innprogrammering krever eksplisitt `--flash`, isolert motorstrøm og
  tilbakeverifisering før programmet resettes.
- **Verktøy:** fysisk diagnostikk bruker PyOCD 0.46.0 i `build/pi-tools/`.
  Automatisk debug-opplåsing er deaktivert. Eksplisitt reset-and-halt før
  flash unngår å starte RAM-flashalgoritmen direkte i en tidligere taskkontekst.
- **CI:** de fire firmwareprosjektene legges til i byggjobben. Workflowen
  er syntakskontrollert; GitHub Actions er ikke kjørt på denne grenen i økten.

## Programverifikasjon

2000 native Ada-kontroller består: 1729 policy/FSM, 24 avstandsmodell,
38 feilgrense, 94 lys, 48 adaptiv skanning og 67 faktisk motor/sikkerhetskode
mot simulert I2C. 40 Python-tester består. Mutasjonstester i isolerte kopier
viser at manglende aldersgrense og overskrivbar feilstatus blir oppdaget.
Det er ikke utført nye formelle bevis.

Alle fire ARM-prosjekter bygger. Hovedprogrammet bruker 228444 B flash og
32424 B i lenkerens SRAM-regnskap. Lysdiagnostikken bruker 155984 B flash og
31624 B SRAM. Dette er ikke observerte stackmaksima eller WCET.

## Faktiske fysiske kontroller

1. Pi-en oppdaget micro:bit V2 på `/dev/ttyACM0`. Første passive 5 s-opptak
   var stille. Det ble ikke tolket som program-/sensorfeil.
2. Hele flashminnet, 524288 byte, og UICR ble sikkerhetskopiert lokalt før
   firmwareendring. GPIO V3s lastesegmenter samsvarte byte for byte med det
   lokale ELF-bildet. Flere bannerstrenger i resten av flash var derfor
   ikke brukt alene som firmwareidentitet.
3. Reset av verifisert V3 og full innsamling ga 320 sammenhengende rader på
   omtrent 26,856 s: 80 front, 160 venstre og 80 høyre. Alle var NO_RISE.
   Brukeren bekreftet etterpå at sensorstrømmen var av. Dette var forventet
   uten strøm og er ingen måling av sensorfeilrate i normal drift.
4. Første flash av lysdiagnostikk feilet med sector erase-timeout og etterlot
   kortet haltet med delvis slettet flash. Feiltilstanden er bevart som
   evidens. Etter eksplisitt reset-and-halt før programmering lyktes neste
   forsøk. Årsaken er forenlig med CPU-/exceptionkontekst, men er ikke endelig
   bevist. Ingen helchip-sletting eller automatisk opplåsing ble brukt.
5. Begge lastesegmenter ble tilbakeverifisert før reset av lysdiagnostikken.
   362 GPIO-registerprøver og seriell moduslogg over 20 s bestod alle seks
   mønstre. Diodene var ikke montert: dette beviser kjøring og registerverdier,
   ikke synlig lys, strøm eller faktisk utgangsspenning.
6. Sluttkontroll: lysdiagnostikk matcher ELF, CFSR/HFSR er 0 og UICR er
   uendret. Kortet står igjen med **lysdiagnostikk uten motor-/servo-I2C**.
   Det siste feilblinkmønsteret er en planlagt demonstrasjon. Autonom firmware
   er ikke flashet, og ingen hjul- eller gulvtest er utført.

## Evidens og dokumenter

`evidence/2026-11-02-lights-scan/` inneholder rå sensorserie, analyse, begge
flashforsøk, firmwareidentitet før/etter, alle GPIO-prøver i CSV-format,
testlogger, mutasjonstester og `verification.json` med kilde-/firmwarehasher.
De opprinnelige binære sikkerhetskopiene og full register-JSON er lokale i
`build/pi-session-2026-11-02/`, ikke publisert som firmwareartefakter i Git.

Rapporten er videreført med avsnitt 7.8, teori, resultatavgrensninger og
kodevedlegg. Presentasjonen er oppdatert til 12 lysbilder. Begge kompilerer
lokalt uten feil eller ordinære advarsler; rapporten har to underfull-meldinger.
Dette er fortsatt en utviklingsrapport som må komprimeres før innlevering.
Oppgaven anbefaler 15–20 sider hovedtekst, kode utenfor sidetallet.

ChatGPT-nettleseren er innlogget, men prosjektlisten og den gamle
ADAptive-samtalen viser lastefeil også etter nytt forsøk. `ISforelesninger.pdf`
og kilde-ZIP-en er derfor **ikke hentet**, og full pensumkontroll er ikke
påstått. Overleaf er heller ikke oppdatert.

## Neste konkrete steg

1. Koble fra USB og ekstern forsyning; monter de fire LED-ene med hver sin
   1 kΩ etter `LYS-OG-SKANNING.md`. Koble så bare USB og observer lyssekvensen.
2. Få pensum-PDF og kilde-ZIP tilgjengelig lokalt i prosjektmappen, ettersom
   ChatGPT-prosjektets Sources ikke kan lastes i den tilgjengelige visningen.
3. Gi sensor-/kortforsyning korrekt strøm med motorene fortsatt sikkert
   fysisk isolert. Først da gjentas sensortest og fysisk I2C-oppstartstest.
4. Flerpunktkalibrering, begge svinger med løftede hjul, målt fart/bremsing
   og lavfartsbane følger før skanning i bevegelse eller dynamisk fart aktiveres.

Fullstendig monteringsplan, matematisk avveining og videre hastighetsmodell
står i `LYS-OG-SKANNING.md`.
