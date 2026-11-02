# Lys og adaptiv skanning – 2. november 2026

Bekreftet oppsett er fortsatt micro:bit V2 / DFR0548, med frontsensor P13/P1,
venstre P14/P2, høyre P15/P8 og servo S2. Brukeren har fire 1 kΩ-motstander;
diodene er ikke montert ennå. Dette oppsettet bruker P0, P12 og P16, slik at
ingen av de tre ultralydsensorenes signalpinner deles med lysene.

## Montering med all strøm frakoblet

Koble fra både micro:bit-USB og bilens eksterne forsyning før du monterer.
Bruk ekspansjonskortets **signalpinne S** merket P0/P12/P16 og **GND**.
VIN/5 V på en eventuell nabopinne skal ikke inn i denne LED-kretsen.

| Lys | Signal | Kobling |
|---|---|---|
| Rødt bak, venstre | P0 | P0 → 1 kΩ → LED-anode; LED-katode → GND |
| Rødt bak, høyre | P0 | Egen gren: P0 → egen 1 kΩ → LED-anode; LED-katode → GND |
| Gult foran, venstre | P12 | P12 → 1 kΩ → LED-anode; LED-katode → GND |
| Gult foran, høyre | P16 | P16 → 1 kΩ → LED-anode; LED-katode → GND |

Anoden er normalt det lange beinet; katoden er normalt kort og ligger ved
den flate siden av LED-huset. Kontroller komponenten hvis bein er klippet.
De to røde LED-ene deler signal, men **ikke motstand**.

```text
P0  ──┬── 1 kΩ ──>| rødt bak venstre ── GND
      └── 1 kΩ ──>| rødt bak høyre   ── GND

P12 ───── 1 kΩ ──>| gult foran venstre ─ GND
P16 ───── 1 kΩ ──>| gult foran høyre   ─ GND
```

Med antatt 3,3 V GPIO og rød fremspenning 1,8 V blir strømmen omtrent
`(3,3 − 1,8)/1000 = 1,5 mA` per rød LED, totalt 3 mA fra P0. Det er en
betinget beregning; faktisk fremspenning og lysstyrke må kontrolleres. Koden
bruker nRF52 high-drive H0H1 for disse utgangene. Pinnefunksjon og
standard-/high-drive-verdier er beskrevet i
[micro:bit-stiftelsens dokumentasjon](https://tech.microbit.org/hardware/edge-connector/).

## Implementert oppførsel

| Kommando/status | Røde baklys | Venstre/høyre |
|---|---|---|
| Parkert eller stoppkommando | Begge på | Av |
| Kjøring rett frem | Av | Av |
| Venstresving | Av | Venstre blinker |
| Høyresving | Av | Høyre blinker |
| Latchet feil | Begge fast på | Begge blinker samtidig |

Bremselyset viser stoppintensjonen. Bilen har ikke en måling som beviser
faktisk nedbremsing/stillstand. Blinkperioden er ett sekund, 50 % påtid.
Blinkfasen starter på ved modusskifte, slik at også en kort sving får et lysglimt.

En egen Ada-task eier GPIO-utgangene og bruker `delay until` med 50 ms
ønsket oppdateringsperiode. Hovedprogram og motorpakke publiserer status til
et protected object. Det objektet inneholder bare korte statusoperasjoner,
ingen GPIO, I2C, logging eller venting. En task-feil blir publisert som
sticky feil og en stoppforespørsel; hovedprogrammet klassifiserer den som
`Lights_Task_Error`. Fault kan ikke overskrives av en nyere kjørekommando.

Perioden er et **mykt mål**, ikke en bevist deadline. Lys-tasken har lavere
prioritet enn den sekvensielle styringen og kan forsinkes av sensorpolling
og bussarbeid. Motor-/sensorarkitekturen er fortsatt sekvensiell; alle
sanntidskrav er ikke dermed analysert eller bevist.

## Egen diagnostikk

Bygg med `python3 tools/build_lamp_diagnostic.py`. Dette lager en egen ELF,
ikke `build/main.hex`. Diagnostikken sender ingen motor-/servo-I2C-kommandoer.
Den viser parkert, venstreblink, høyreblink, kjøring og brems i tre sekunder
hver, deretter feilblink som siste demonstrasjonsmønster. Det siste mønsteret
er en planlagt demonstrasjon, ikke i seg selv en detektert kjøretøyfeil.

`tools/lamp_experiment.py` kan verifisere bildet, resette bare den kjente
lysdiagnostikken og sammenligne seriell status med nRF52s GPIO-utgangslatcher.
Det krever isolert motorstrøm og eksplisitt bildevalg for flashing. Den tidligere 362-prøverserien gjelder eldre diagnostikkhash, ikke dagens
nybygg. Register-
observasjoner beviser ikke at monterte LED-er lyser eller trekker riktig strøm.

## Skanning som avslutter ved første akseptable korridor

Den aktive navigasjonen har nå en generisk, testbar søkestrategi:

1. Stopp og kontroller alle tre sensorer med fronten sentrert.
2. Er det allerede klart fremover, avslutt uten sidepunkter.
3. Er svingklareringen utilstrekkelig/ukjent, avslutt uten å skanne forgjeves.
4. Prøv siden med størst målt sideklaring først; ved likhet behold forrige
   svingretning. Høyre bruker 72°/60°, venstre 96°/108°.
5. En ugyldig/blokkert stråle forkaster kandidatparet straks. Et tilstrekkelig
   bredt par må også bestå en ny sentrert kontroll av alle tre sensorer.
6. Forkast paret hvis eldste måling er over 2000 ms gammel. Tidsstempelet
   beholdes og sjekkes også etter siste live-kontroll før svingkommandoen. Prøv ellers den
   andre siden, og avslutt etter høyst fire sidepunkter. En ny sentrert
   måling med fri front kan også avslutte søket med kjøring rett frem.

De tidligere faste 5-/7-punktsrundene brukes ikke lenger i aktiv `Scan_Path`.
Historiske policyfunksjoner og regresjonstester beholdes. Fire sidepunkter
betyr opptil fire servoposisjoner, ikke bare fire råavlesninger: hver posisjon
filtrerer tre avlesninger, og sentrerte sensorkontroller kommer i tillegg.
Servoens tidligere 0,5 s stabilisering beholdes inntil bevegelsen er målt.
Ved sentrering leses de faste sidesensorene mens frontservoen stabiliseres.
Alle tre filterprøver per sensor beholdes; fronten avleses først etter
minst 500 ms fra sentreringskommandoen. Global 65 ms triggerpacing gjelder.
Loggen angir punktantall, foreldede par, tidsbruk og valgt retning.
Den ekstra servo-/filterrunden i Turn er fjernet fordi skanningen allerede
returnerer sentrert med ny kontroll; live-kontrollen beholdes. Utløpt evidens
gir stopp. Fysisk skannetid må måles før dette alderbudsjettet godkjennes.

Søkets mål er liten stoppetid til **første tilstrekkelig klarerte kandidat**.
Det søker ikke globalt etter den bredeste eller korteste ruten. For to
kandidater med suksessannsynlighet `p_i` og kostnad `c_i` minimeres forventet
søkekostnad ved å prøve størst `p_i/c_i` først. Vi har ingen målte
suksessannsynligheter; sideklaring er foreløpig en eksplisitt heuristikk.

Geometrien viderefører korridorfilteret `w = 2*d*sin(Δθ/2)`. Med 12° mellom
strålene og krav `16 + 2*5 = 26 cm` trengs omtrent 124,4 cm avstand i paret.
Sparsomme ultralydstråler beviser ikke at hele arealet mellom dem er tomt.
2000 ms er et prosjektert ferskhetsbudsjett, ikke en sikkerhetsgaranti for
bevegelige hindringer. Databladet anbefaler mer enn 60 ms målesyklus;
prosjektets globale 65 ms mellom triggere beholdes.

## Hva som gjenstår før skanning i bevegelse

Jevnere kjøring krever oppmålt fart, bremsing, sensorlatens og servoens
innstillingstid. For en kalibrert modell kan sikker fart begrenses med

`v_max = sqrt((a*t)^2 + 2*a*(d - margin)) - a*t`.

Dette følger ved å løse `v*t + v²/(2*a) <= d − margin` for ikke-negativ fart.
PWM er fortsatt ingen målt fart. Denne dynamiske modellen er foreløpig en
plan; den nye implementasjonen **skanner stasjonært** og beholder alle
eksisterende stoppgrenser. Kontinuerlig kjøring rett frem bruker fortsatt
front–venstre–front–høyre-kontroll uten å stoppe for hver godkjent måling.

Det finnes ingen dokumentert «matematisk beste» navigasjonsløsning uten å
avklare mål, modell og måledata. Denne endringen begrenser ekstra sidepunkter
og gjør avveiningen etterprøvbar uten å late som bilen har fartstilbakemelding.
