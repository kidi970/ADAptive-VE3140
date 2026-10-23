# ADAptive – utvikling og benketester 23.10.2026

## Resultat og avgrensning

Oppstartsregresjonen er rettet. En isolert økning av primærstakken fikk
samme applikasjon videre fra OLED til FSM og servoskanning. Utvikler
bekreftet fysisk servobevegelse. Den modulære versjonen ga fremoverkjøring
ved PWM 800 og stopp ved ugyldig venstremåling og frontmåling 44 cm.
Utvikler bekreftet at hjulene dreide fremover og stoppet.

Stabil autonom demonstrasjon er **ikke ferdig verifisert**. Venstresensoren
gir periodiske 0-målinger også med målflate. Årsaken er ikke fastslått.
Ingen gulvkjøring, målt bremselengde, WCET, full svingtest eller elektriske
spenningsmålinger er gjennomført. 5 V / 3 A er oppgitt forsyning, ikke en
måling av faktisk spenning under belastning.

## Sikring og opprinnelig feil

Arbeidsgrunnlag: `ee6df67` med omfattende lokale endringer. Før endringer
ble 51 lokale filer sikkerhetskopiert med SHA-256-manifest, sammen med
arbeids- og indeksdiff for hovedrepo og undermodul. Full flashkopi på
524288 byte og den opprinnelige ELF-filen ble bevart utenfor repoet i:

`C:\Users\jacob\OneDrive\Documents\ChatGPT\ADAptive\backups\baseline-2026-10-23`

Programområdet i flash var byteidentisk med lokal `build/main.bin`.
Feiltilstand: PC `0x16c08`, xPSR `0x21000006` (UsageFault), CFSR
`0x40000` (ugyldig exception return). PSP `0x200031b0` lå under
primærstakkens nedre grense `0x20003260`, i interruptområdet. Main hadde
3424 byte statisk ramme på en primærstakk på 4096 byte, før underkall.

Isolert retting: linkerparameter `--defsym=__stack_size=16384`.
Etter flashing kom autonom FSM og 5P/7P i gang, med CFSR=0. Dette støtter
stakkoverløp som dokumentert årsak til oppstartsfeilen. Det isolerer ikke
én bestemt kildekodelinje i den siste 1P-endringen som eneste årsak.

## Implementasjon

- `adaptive_policy`: gyldighet, konservativ filtrering, grenser og
  korridorbredde. Alle tre stasjonære prøver må være gyldige; to må stemme
  innen 15 cm. Minste prøve beholdes. 0 og verdier utenfor 2–200 cm gir
  aldri kjøretillatelse. Stopp ved front <=45 cm.
- `adaptive_fsm`: ren, testbar overgangslogikk og to like utvidede valg
  før sving. Feil låses; uventede hendelser stopper.
- `adaptive_sensors`: sekvensiell lesing med minst 65 ms mellom akustiske
  triggere. Råverdier logges bare ved stasjonær filtrering.
- `adaptive_navigation`: 5P, deretter 7P og informative 1P-målinger ved
  blokkering. En enkelt fri stråle opphever aldri en blokkert korridor.
  Bevegelse overvåkes i rekkefølgen front, venstre, front, høyre. Ugyldig
  eller for nær råverdi stopper motorene før neste måling og før logging.
- `adaptive_motion`: kontrollerte I2C-skrivinger, stopp og servogrenser.
  Samme PWM 800 beholdes. Ingen generell I2C-reset av skjermen.
- `adaptive_display`: bevart OLED-font og LED-funksjoner i egen modul.
- `adaptive_safety`: knapp B og diagnostisk stoppforespørsel låser videre
  kjøring. Ingen I2C eller logging i knappens avbruddscallback.

Main er fortsatt en sekvensiell applikasjon. Det er ikke innført sensor-,
motor- eller sikkerhetstasks. Kompilatoren oppgir 912 byte dynamisk ramme
for Main, som ikke er en fullstendig øvre stakkgrense.

Utvikler bekreftet mekanisk fritt område 34–134 grader, og oppga bredde
16 cm, lengde 23 cm og sensorforskyvning omtrent 10 cm. Breddevurderingen
krever `2*d_min*sin(span/2) >= 26 cm`, inklusive 5 cm tillegg på hver side.
Målene er utvikleropplysninger. Sonarstråler, sensorplassering, blindsoner,
hele svingbanen og fysiske marginer er ikke fullt verifisert.

## Drivere og advarsler

De undersøkte ultralydløkkevariantene hadde allerede eksplisitte 3 og
23 ms tidsavbrudd. Advarsler om at Echo ikke ble endret var derfor ikke
bevis på en uendelig løkke og forklarte ikke UsageFault-regresjonen.
Løkkene bruker nå klokkesammenligning i betingelsen og returnerer 0 ved
timeout. Tidene er programmerte grenser, ikke målt WCET; avbrudd og
pollingoverskridelse må inngå i senere analyse.

I2C-sendestien ignorerte tidligere Timeout. Den er nå avgrenset både ved
dataoverføring og venting på STOP. Motorutgang bruker 20 ms som parameter
og låser kjøring ved feil. En ødelagt buss kan fortsatt forhindre at en
stoppordre når motorbrettet. Fysisk frakobling må være tilgjengelig.
Receive/Mem_Read er ikke brukt av den nye kontrollstien og er ikke
fullstendig gjennomgått eller tidsavgrenset i denne endringen.

`patches/ada-drivers-2026-10-23.patch` er **kumulativ** mot undermodulens
opprinnelige HEAD. Den erstatter behovet for først å bruke 21.10-patchen.
Kontroll mot en isolert, ren kopi bekreftet at patchen kan anvendes og
gjenskaper alle tre endrede drivere. Undermodulen beholder egne lokale
endringer; gitlink er ikke flyttet til en upublisert submodule-commit.

## Utførte tester

| Kontroll | Resultat | Bevis/avgrensning |
|---|---|---|
| `python tools/mb.py build` | Bestått | Siste kildebygg i `evidence/2026-10-23/build.txt` |
| Native Ada-policy/FSM | 1729 kontroller bestått | `python tools/test_navigation.py`; faktiske moduler, ikke en Python-kopi |
| Kumulativ driverpatch | Bestått | Anvendelse på ren baseline og sammenligning av alle tre filer |
| Isolert stakkretting på micro:bit | Bestått | FSM og skanning, CFSR=0; fysisk servo bekreftet |
| Modulær blokkert scene | Bestått innen testomfang | Front ca.25, venstre ca.100 og høyre16; 5P/7P/1P; ingen kjøretillatelse |
| Frigjort måleområde | Sikkert blokkert | Front0, venstre0, høyre67; ytterpunkter55/76 opphevet ikke blokkeringen |
| Målflater, 15 sekunder | Fremover og stopp | Gyldig64/63/75, PWM800; stopp ved venstre0 og senere front44; fysisk respons bekreftet |
| Gjentatt målflatetest, 15 sekunder | Fremover og sikkert stopp | Gyldig65/69/74, deretter venstre0; periodisk venstrebortfall bekreftet |
| Stakkmarkør, målflatetester | 2240 byte observert brukt | 14144 byte av primærstakken urørt; ikke en verstefallsgrense |
| Avslutning | Stoppforespørsel=1, motorkommando=0 | CFSR=0; mål stoppet/haltet etter hver opptaksøkt |

Rå logger ligger i `docs/evidence/2026-10-23/`. Det første modulære
serieopptaket inneholder én bufret linje fra forrige firmware før den nye
oppstartsmarkøren. Detaljer for det aktuelle bygget begynner ved
`ADAptive MODULAR START`. Verktøyets flaggsampling er ikke et oscilloskop
og dokumenterer ikke varighet eller fysisk motorbevegelse; sistnevnte er
utviklerens uttrykkelige observasjon. Registersamplene i `target-repeat`
ble tatt med debuggerens datacache deaktivert.

Siste bygg: **215748 byte flash (41,15 %)** og **29000 byte reservert SRAM
(22,13 %)**. `size` oppgir tekst 215744, data3832 og bss25168; regionrapporten
og seksjonssummen har ulike avgrensninger. ELF/HEX/BIN-hasher er lagret.
Ingen tidligere ultralydadvarsler forekom etter omskrivingen. Ved første
bygging av TWI-driveren kom fire eksisterende advarsler om parenteser i
arrayaggregater; det påstås ikke at hele kodebasen er advarselsfri.

## Reproduksjon

I en ny kopi ved denne lokale commiten, med samme undermodul:

```text
git submodule update --init --recursive
git -C Code/libs/Ada_Drivers_Library apply --check ../../../patches/ada-drivers-2026-10-23.patch
git -C Code/libs/Ada_Drivers_Library apply ../../../patches/ada-drivers-2026-10-23.patch
python tools/mb.py build
python tools/test_navigation.py
```

Hvis undermodulen allerede har lokale endringer, skal patchen ikke
anvendes blindt. Kontroller baseline og ta backup først. Native tester
krever `gnatmake` på vertsmaskinen, ARM-bygg krever prosjektets Alire-miljø.

For en eksplisitt benketest etter at hjulene er løftet og motorstrømmen
kan kobles raskt fra:

```text
python tools/bench_capture.py --flash --seconds 15 --output docs/evidence/new-bench
```

Dette bruker COM5 og micro:bit-debugproben. Verktøyet ber om stopp ved
avslutning og lar prosessoren være haltet. Reset starter autonom kode på
nytt. `tools/mb.py flash` fant ikke proben via sitt CLI-oppslag i denne
sesjonen, selv om `python -m pyocd` nådde den. Bygget gikk gjennom det
pålagte `mb.py build`; flashing brukte `python -m pyocd load`.

## Rapport og det som gjenstår

Den faktiske Overleaf-kilden ble eksportert før endringer. Den hadde både
TikZ-rettingen og en endret KI-deklarasjon som den lokale rapportkopien
manglet. Disse endringene er bevart. En datert utviklingsdel, testtabell,
FSM-figur, forelesningsreferanse og nye redigerbare kodevedlegg er lagt til.
Eldre kapitler og kodevedlegg beskriver fortsatt uttrykkelig 21.10.

Før demonstrasjon må venstrebortfall undersøkes fysisk: målflate og
innretting, kontakt og jordforbindelse, forsyning under belastning og
mulig akustisk interferens. Dette er undersøkelsespunkter, ikke fastslåtte
årsaker. Deretter testes begge svinger, sidehindringer, knapp B, feiltilfeller
og drift uten USB. Hastighet og fysisk stopplengde må måles før tidskrav
kan erklæres oppfylt. Sikkerhetsreglene skal ikke omgås for å få jevn kjøring.

## Verifisert rapportlevering

Siste Overleaf-kompilering: 42 sider, 0 feil, 0 ordinære advarsler og to
underfull-typesettingsmeldinger i bevart tekst/bibliografi. Den ene
overfull-linjen i tillegget og en uheldig pilføring i FSM-figuren ble
rettet før siste kompilering. PDF er lastet ned fra Overleaf, med alle
skrifter innebygd og uten ??-henvisninger eller tomme sider. Endrede sider
er kontrollert i full størrelse, hele dokumentet i sideoversikter.

## Videre arbeid i samme dato: referanse 60 cm

Den videre sensorøkten er dokumentert i [ADAptive-reference60-2026-10-23.md](ADAptive-reference60-2026-10-23.md). P0 er fortsatt åpent; ingen nye hjul- eller gulvtester er utført.
