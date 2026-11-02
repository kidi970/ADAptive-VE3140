# ADAptive: faglig sporbarhet og demonstrasjon

Arbeidsgrunnlag 2. november 2026 er oppgaveteksten som følger repoet, den
eksisterende rapporten og inspisert kode. Selve `ISforelesninger.pdf` og en
gjeldende sensurveiledning er ikke tilgjengelig i dette checkoutet. Historiske
henvisninger til forelesningssider er ikke kontrollert på nytt. Avklar disse
kildene, fristen og kravene til presentasjonen før endelig pensumdekning fastslås.

Oppgaven ber om en fungerende Ada/micro:bit/Mecanum-prototype, LaTeX/Overleaf,
deadlines med begrunnet analyse, teori, prosjektgjennomføring og GitHub-lenke.
15–20 sider er oppgavens anbefalte rapportomfang; vesentlig Ada-kode ligger
utenfor sidetallet. Hovedteksten er nå komprimert til 17 sider pluss én referanseside.
Utviklingshistorikken er bevart separat i `development-history.tex`,
og alle gjeldende applikasjonsenheter ligger i kodevedlegg.

| Faglig tema | Kode / dokumentasjon | Evidens og neste avklaring |
|---|---|---|
| Sterk typing, pakker og grenser | `Adaptive_Policy`, `Adaptive_Motion`, `Adaptive_Errors` | Native Ada-tester og ARM-bygg; mekaniske grenser krever fysisk bekreftelse |
| Exceptions og propagation | Navngitte exceptions, klassifisering og `Adaptive_Fault_Handler` | Feilinjeksjon ved alle 12 oppstartsskrivinger, sekundær stoppfeil og loggerfeil |
| Tilstandsmaskin og integrasjon | `Adaptive_FSM`, sensorer → navigasjon → motor | 521 kontroller av faktisk generisk styring, 22 scenarier; fysisk løype ikke validert |
| Delt ressurs / I2C | Motor og OLED deler ekstern buss; unngå dobbel initialisering | 20 ms parameter per skriving; fysisk bussfeil fortsatt åpen |
| Tasking og protected objects | Implementert lys-task og beskyttet lysstatus; motor/sensor fortsatt sekvensielle | Native samtidighetstest og fysisk GPIO-registertest; full RTA gjenstår |
| Perioder, deadlines og responstid | Eksisterende sekvensiell sampling og stoppforespørsel | Mål triggerintervaller, opptakstid og verst observert reaksjon på målmaskinen |
| Matematisk modell og usikkerhet | Pulsmodell, filter, geometri og sensoranalyse | Fysiske 60 cm-data finnes; ny flerpunktkalibrering og målt bremsing gjenstår |
| SPARK og kontrakter | Faktisk `Adaptive_Lamp_Policy` med postcondition | 4 analysekontroller, ingen ubeviste; bevismutasjon avvises. Ingen helbil-/tidsbevis |
| Testbarhet og reproduserbarhet | Native Ada, simulert I2C, Python og rådata | Skill programtest, ARM-bygg, fysisk forsøk og formelt bevis |

## Gjeldende taskarkitektur og mulig videre oppdeling

Oppfølgingen har nå implementert en separat lavprioritets lys-task med
50 ms myk periode og et protected object uten I2C eller venting. Det gir
uavhengig blinking uten å innføre parallelle eiere av motorbussen. Beskrivelsen
nedenfor gjelder videre oppdeling av sensor-, navigasjons- og motorstyring.

Ikke la flere tasks trigge ultralyd eller skrive I2C samtidig. En mulig
fordeling er én akustisk sensor-eier, én navigasjonstask og én motor-eier.
Del tidsstemplete sensordata og ønsket bevegelse gjennom protected objects.
Et stoppflagg må prioriteres over en eldre bevegelseskommando. OLED/logging
skal ikke ligge foran kritisk stopp i en kø. Feil i hver task må fanges ved
taskgrensen og varsle supervisoren; en exception i en task propagates ikke
som en vanlig subprogram-exception inn i en annen task.

Gjeldende `Adaptive_Fault_Handler` har én sekvensiell eier. Den er ikke en
trådsikker supervisor for den planlagte taskarkitekturen. Ada-tasking som
allerede finnes internt i kortbiblioteket er heller ikke de planlagte
applikasjonstaskene.

## Analyse som svarer til koden

For dagens sekvensielle kjerne beregnes end-to-end-respons fra tidsrommet til
neste relevant måling, begrenset sensorlesing, beslutning og stopptransaksjon.
Ved usikker auto-increment bruker stopp opptil åtte enkelttransaksjoner med
20 ms parameter hver: **160 ms i transaksjonsbudsjetter**, pluss program- og
schedulerbidrag. Dette er ikke en målt eller bevist fysisk stopptid.

Når periodiske applikasjonstasks faktisk er innført, må en passende RTA-modell
inkludere WCET, perioder, release jitter, prioriteter, blokkering og eventuelle
self-suspensions. De ventende operasjonene kan ikke uten begrunnelse behandles
som en enkel CPU-jobb. Maksimal observert kjøretid er ikke et bevis for WCET.
Kriteriet `R_i <= D_i` brukes først med dokumenterte forutsetninger og verdier.

Den dynamiske stoppmodellen er `d = v*t + v²/(2*a) + margin`. Verdiene må komme
fra oppmålt fart, bremseretardasjon og reaksjonstid. PWM 800 er en kommando,
ikke fart i cm/s. PID og sensorfusjon er først aktuelle med fungerende og
karakteriserte tilbakemålingssensorer.

## Demo som må bestås, i rekkefølge

| Trinn | Forventet resultat | Må registreres |
|---|---|---|
| 1. Oppstart, motorstrøm isolert | READY uten kjøring; A gir arming, B låser stopp | Firmwarehash, oppstartslogg, forsyning og oppsett |
| 2. Alle tre sensorer | Gyldighet og feilrate ved flere oppmålte avstander | Referansedatum, rådata, usikkerhet, MAE/RMSE |
| 3. Hjul løftet | Riktig retning på alle motorer og begge svingretninger | Motorkart, PWM, observasjon og stopp |
| 4. Lav fart på avgrenset bane | Kjører frem og stopper foran målt hindring | Hastighet, reaksjonstid, minste avstand og repetisjoner |
| 5. Autonom sekvens | Frem → hindring → stopp → skann → trygg sving → ny kontroll | Sammenhengende video/logg og alle feilforsøk |
| 6. Feilscenario | Ugyldig sensor og stoppknapp gir kontrollert stopp | Trigger → bekreftet kommando → faktisk stillstand |

Avbrutt I2C og sekundær stoppfeil demonstreres først i feilinjeksjon uten
motorer. En I2C-feil kan gjøre programvarestopp umulig. Fysisk strømfrakobling
er derfor en del av testoppsettet. Det gis ingen karaktergaranti; faglig verdi
ligger i korrekt implementasjon, forklaring og etterprøvbare resultater.
