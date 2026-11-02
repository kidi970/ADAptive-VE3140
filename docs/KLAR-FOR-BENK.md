# ADAptive: klar for neste benkerunde

Programvarekontroll 2. november 2026: 2599 Ada-kontroller, 40 Python-tester,
fem avviste kildemutasjoner, én avvist SPARK-mutasjon, fire ARM-bygg og begge
PDF-er. Dette er ikke en fysisk akseptanse av den nye autonome versjonen.
Kortet er ikke lest, resatt eller programmert i denne gjennomgangen. Det står
med lysdiagnostikken fra tidligere økt.

## Ferdig i programvaren

- Oppstart er ett forsøk. Knapp A gir startforespørsel; før A sendes ingen
  kjørekommando. B låser stopp frem til omstart og har forrang over A.
- Én kontroller eier sensor-/servo-/motorflyten. Cruise fortsetter uten
  stopp/start når avlesningene er gode. Stopp skjer før feiltekst og neste
  måling; et B-trykk under en avlesning sjekkes etterpå.
- Alle åtte motor-PWM-kanaler får eksplisitt FULL_OFF ved stopp. Busssvikt
  opphever motorberedskap; den første feilen og eventuell stoppfeil lagres.
- OLED deaktiveres ved første mislykkede sending, uten forsøk fra hver
  senere tekst. Den lokale LED-matrisen beholder retnings-/stoppvisning.
- Lys har egen task og protected status. Logikken for utgangsmønstrene
  har en faktisk SPARK-kontrakt som er verifisert. Dette beviser ikke
  lys-taskens timing, strøm eller fysiske LED-er.
- Adaptivt søk prøver høyst fire sideposisjoner og avslutter tidlig.
  Tidspunktet for eldste stråle beholdes. Det må fortsatt være innen
  2000 ms etter siste live-kontroll før sving. En ekstra servo-/filterrunde
  før sving er fjernet. Sidemålinger overlapper servosentreringen; alle
  filterprøver og 500 ms venting før frontmåling beholdes. Hvis arbeidet likevel tar for lang tid, avvises svingen.

Kjør alle kontroller uten tilgang til bilen:

```sh
python3 tools/check_project.py --full
```

Etter en kodeendring oppdateres rapportens genererte kildekopi først:

```sh
python3 tools/sync_report_sources.py
python3 tools/check_project.py --full
python3 tools/package_delivery.py
```

Alle tre kommandoer arbeider med filer og programtester. Ingen av dem
åpner seriellport, resetter eller flasher micro:biten. Logger og kildehash
ligger i `build/readiness-review/`; leveransen i `build/deliverables/`.
Et nytt checkout trenger den låste undermodulen og driverpatchen én gang,
se [Pi-oppsettet](PI-OPPKOBLING.md).

## Fysisk rekkefølge og akseptanse

| Trinn | Gjennomføring | Bestått når |
|---|---|---|
| 1. Lys | Monter med både USB og ekstern strøm frakoblet. Følg [lysplanen](LYS-OG-SKANNING.md). | To røde på P0 har hver sin 1 kΩ; venstre P12 og høyre P16 har hver sin 1 kΩ; ingen feilpolaritet/kortslutning. |
| 2. Lysdiagnostikk | Bruk det kjente diagnostikkbildet, med motorstrøm isolert. Kontroller alle seks mønstre. | Riktig LED på riktig side, begge baklys virker og strøm/lysstyrke er akseptable. Tidligere GPIO-test erstatter ikke dette. |
| 3. Buss/oppstart | Bekreft kjent ny firmwarehash før første autonome reset. Motorstrøm holdes isolert. Kontroller oppstartslogg med og uten OLED. | Kommer til READY og blir stående uten A; motorinitialisering virker og en manglende OLED gir én melding om deaktivert OLED. |
| 4. Sensorer | Korrekt forsyning, felles GND og kontrollert ECHO-nivå. Mål alle tre kanaler ved flere referanseavstander. | Ingen feil spenning, dokumentert feilrate/bias og ingen ugyldig måling tolket som fri bane. Bruk [sensorprotokollen](SENSORPROTOKOLL.md). |
| 5. Hjul løftet | Bekreft alle motorfortegn, rett frem og begge svingretninger. Test A og B. | Ingen start før A; B stopper og nytt A kan ikke oppheve stopp. Fysiske retninger svarer til kommandoene. |
| 6. Skannetid | Mål kandidatens alder helt frem til sving, servostabilisering og alle avvisninger. | Begge kandidatrekkefølger kan testes; gamle par fører aldri til kjøring. Ikke øk alderbudsjettet bare for å få testen grønn. |
| 7. Lav fart | Avgrenset bane med tilgjengelig fysisk motorfrakobling. Mål fart, reaksjon og stillstand. | Valgt deadline og minste klaring er begrunnet i rådata og stoppmodellen; kravtabellen oppdateres. |
| 8. Autonom løype | Frem → hindring → stopp → skann → sving → ny kontroll → frem. Gjenta med begge retninger. | Sammenhengende rålogg/video, registrerte feilforsøk og beståtte kriterier i samme firmwareoppsett. |

Knapp B er en programvarebasert stoppforespørsel. Den er ikke dokumentert som
en uavhengig hard nødstopp. Fysisk motorfrakobling må være mulig i forsøket.
PWM 800 er fremdeles ingen kjent fart. Ingen ny gulvkjøring er godkjent her.

Før hver serie registreres dato, firmware-SHA256, forsyning, referansepunkt,
oppsett og forventet resultat. Bruk [tom målemal](templates/bench-results.csv)
og behold rålogg/video. Tomme felt er planlagte målinger, ikke resultater.

## Dokumentarbeid som fortsatt krever grunnlag fra gruppen

Hovedteksten er 17 sider pluss én referanseside. Forside, sammendrag/innhold
og kodevedlegg kommer i tillegg; PDF-en er 47 sider totalt. Presentasjonen
har 12 lysbilder. Tidligere 60-sidersrapport er bevart i
`development-history.tex` og i den forrige PDF-leveransen.

Følgende kan ikke fylles ut sannferdig fra programkoden alene:

- De fysiske måleverdiene, endelige deadlines og bestått autonom demonstrasjon.
- Faktisk arbeidsfordeling, gruppens erfaringer og fullstendig KI-deklarasjon.
- Sammenligning med `ISforelesninger.pdf` og gjeldende vurderingskriterier.
  Filene er oppgitt som prosjektkilder i ChatGPT, men innholdet er fortsatt
  utilgjengelig i dette arbeidsområdet. Ingen full pensumkontroll er påstått.
- Eksakte leverings-/demodatoer og eventuell oppdatert presentasjonsinstruks.

Den bevarte oppgaveteksten er kontrollert: Ada/micro:bit/Mecanum,
LaTeX/Overleaf, deadlinebegrunnelse, teori, prosjektgjennomføring,
GitHub-lenke og kodevedlegg er dekket som struktur. Oppfylte fysiske
funksjons- og tidskrav må legges inn etter forsøkene. Overleaf er ikke
oppdatert i denne gjennomgangen; ZIP-pakken er klargjort for opplasting.
