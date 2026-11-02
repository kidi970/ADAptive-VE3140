# Programvaregjennomgang og leveranse – 2. november 2026

Arbeidet følger ønsket om å gjøre ferdig mest mulig før lysene monteres.
Ingen USB-/seriellport, debug-probe eller GPIO er åpnet i denne gjennomgangen.
Kortet er ikke resatt eller programmert; tidligere lysdiagnostikk er beholdt.
Den nye autonome versjonen er bygget, men ikke fysisk validert.

## Endringer som betyr noe for kjøringen

1. **Bevisst start:** Knapp A gir startforespørsel. Oppstart alene kjører
   ikke bilen. Kontrolleren og motorpakken håndhever dette. Knapp B setter
   bare et atomisk stoppflagg i avbruddet og har forrang over A. Frigivelse
   eller nytt A-trykk opphever ikke stoppen.
2. **Testbar reell kontroller:** `Main` binder drivere til den generiske
   `Adaptive_Controller`. Den faktiske kontrollflyten testes gjennom 22
   scenarier. Initialisering er ett forsøk, og enhver propagert feil låser
   kontrolleren før ytre feilhandler forsøker stopp. Ny kjøring kan ikke
   gjenopptas fra en feiltilstand.
3. **Entydig motorstopp:** Også samlet stopptransaksjon setter FULL_OFF
   eksplisitt på alle åtte motorkanaler. Ukjent auto-increment bruker
   fortsatt separate registeradresser. Kvittering betyr ikke fysisk stillstand.
4. **Mindre unødig bussarbeid:** OLED sperres etter første feil og forsøkes
   ikke på nytt for hver tekst. Motor- og skjermpakke beholder én eier av
   ekstern I2C. Lokal matrisevisning overlever manglende OLED.
5. **Stopp under sensorarbeid:** Stoppflagget sjekkes før/etter pacing og
   etter en avlesning. Ingen ny ultralydtrigger sendes etter latchet stopp.
6. **Fersk svingevidens:** Skanningen bevarer eldste stråletid. Alder sjekkes
   også etter siste live-kontroll før kjøring. Den tidligere ekstra
   servo-/filterrunden før sving er fjernet fordi skanningen returnerer
   sentrert med ny klarering.
7. **Utnyttet servoventing:** Faste sidesensorer filtreres mens frontservoen
   sentreres. Alle tre prøver per sensor og global 65 ms pacing beholdes.
   Fronten leses først etter minst 500 ms fra sentreringskommandoen. Dette
   gir mer margin til 2000 ms-grensen uten redusert frontstabilisering.
8. **Faktisk formelt bevis:** Den eksisterende lyspolicyen, både spec og body,
   er analysert i SPARK med en konkret utgangskontrakt. Ingen GPIO-, timing-
   eller helbilverifikasjon påstås.

## Resultater

| Kontroll | Resultat |
|---|---|
| Native Ada | 2599 kontrollpunkter består, med assertions og overflow-sjekker |
| Kontroller | 521 kontroller over 22 scenarier, inkludert begge svinger, feil og utløpt evidens |
| Faktisk navigasjon mot fakes | 30 kontroller; full skanning, 24 råprøver, korrekt venting og etterfølgende live-kontroll |
| Python | 40 tester består |
| Kildemutasjoner | 5 kompilerer og avvises av testene |
| SPARK-mutasjon | Feil bremselys i Moving gir avvist postcondition og feilretur |
| GNATprove | 4 samlede analysekontroller, ingen ubeviste; én faktisk produksjonsenhet |
| ARM | Hovedprogram, sensor V2, GPIO V3 og lysdiagnostikk bygger |
| Hovedprogrammets linkerbruk | Flash 229452 B av 512 KiB; SRAM 32440 B av 128 KiB |
| Dokumenter | 17 sider hovedtekst + 1 referanseside; 47 totalt med frontstoff/kode. 12 lysbilder |

Linkerbruk er ikke en måling av maksimal stakkbruk. Vertens skannetid er
ikke målmaskinens WCET. Fem mutasjoner dekker manglende arming, utløpt
svingevidens, OLED-forsøksstorm, manglende FULL_OFF og for tidlig frontmåling.
Mutasjonene finnes bare i midlertidige kopier; arbeidskoden skades ikke.

De nye testene bygger direkte mot applikasjonspakker, mens fakes erstatter
I2C, knapper, konsoll, lokal matrise og ultralyd. ARM-bygget bekrefter den
konkrete bindingen. Dette beviser logiske egenskaper innen testoppsettet,
ikke strøm, krysstale, motorbevegelse eller deadlines.

## Rapport og presentasjon

`main.tex` bruker nå `report-body.tex` og ti seksjonsfiler som beskriver dagens
kode. Originalens krav-ID-er, navn, studentnumre og kapittelstruktur er
videreført. Den gamle hovedkilden er bevart **byteidentisk** som
`development-history.tex`, SHA-256
`e70a421a9dc0b5ef29f2837909dea0dcea761481200dec1e71f05c23405afcaa`.

Alle 35 Ada-filer i `Code/src/` inngår i nytt vedlegg. Totalt 45 kilde-/
konfigurasjonsfiler kopieres til `code/current/` og kontrolleres byte for byte.
Historiske kodesnapshots er ikke brukt som gjeldende implementasjon.
Rapportens sanntidsmodell beskriver faktisk sekvensiell styring og den
separate lys-tasken. Den inneholder en stoppmodell, relevant RTA med
forutsetninger, parameterbudsjett og en konkret måleplan. Ingen tidsverdier
eller gruppemedlemmers bidrag er funnet på.

Begge PDF-er er kompilert lokalt. Ingen udefinerte referanser eller
overfulle bokser står igjen. Én underfull tekstlinje i faglig sporbarhet er
et typografisk varsel. Utvalgte rapportsider og alle lysbilder er inspisert
som bilder. Overleaf-prosjektet er ikke endret; kildepakken er klargjort.

## Reproduksjon og sporbarhet

```sh
python3 tools/sync_report_sources.py --check
python3 tools/check_project.py --full
python3 tools/package_delivery.py
```

`check_project.py` registrerer returkoder og kildehash. Pakkeverktøyet krever
bestått full kontroll og avviser endret kode eller LaTeX etter kontrollen.
ZIP-CRC og innholdet i hver post sammenlignes med originalfilene.

Rålogger, bevisoppsummering og firmwarehash ligger i
[evidence/2026-11-02-readiness](evidence/2026-11-02-readiness/).
Verktøykjeden er låst via Alire. Undermodulens revisjon er uendret,
`8e90f85575666684cc6e0b51830494de259bd3bc`; eksisterende driverpatch er
kontrollert med omvendt apply-sjekk, og skal fortsatt anvendes én gang i et
nytt checkout. Kompilert firmware/PDF og lokale verktøy holdes utenfor Git.

GitHub-oppsettet er utvidet med disse kontrollene og dokumentbygg. Lokale
resultater over er dokumentert uavhengig av en ekstern Actions-kjøring.

## Det som må fullføres etterpå

Se [klar-for-benk](KLAR-FOR-BENK.md) for trinn og akseptansekriterier.
De tidligere 362 GPIO-prøvene gjelder eldre diagnostikk, uten monterte
lys. De 320 NO_RISE-prøvene ble tatt uten sensorstrøm. Ingen av disse
seriene godkjenner dagens nye autonome firmware.

Monter lys, kontroller forsyning/ECHO og den åpne fysiske I2C-oppstarten,
test løftede hjul og mål skannetid/fart/bremsing før gulvkjøring.
Pensum-PDF/sensurveiledning, gruppens faktiske arbeidsfordeling,
KI-deklarasjon og endelige frister må avklares før innlevering.
