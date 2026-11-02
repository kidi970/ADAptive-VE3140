# Arbeidsmanus til de 12 lysbildene

Forslag til omtrent 8–10 minutter, før eventuell live-demonstrasjon.
Tilpass tiden til fagets instruks. Alt om fysisk funksjon må oppdateres
etter benketesten; dagens manus hevder ikke en ferdig autonom bil.

| Lysbilde | Hovedpoeng å forklare med egne ord |
|---|---|
| 1. ADAptive | Vi undersøker autonom styring med micro:bit og Ada, med særlig vekt på samspill og etterprøvbar feilrespons. |
| 2. Problem | Vis den konkrete sekvensen: frem, hindring, stopp, skann, sving, ny kontroll. Skill programmert funksjon fra det som er fysisk demonstrert. |
| 3. Arkitektur | Pi-en bygger og logger. micro:biten tar beslutningene. Én foreground-eier styrer sensor/I2C; én egen task styrer lys. USB er ingen nødstopp. |
| 4. Normal flyt og feil | En hindring er normal kontrollflyt. En motorbussfeil er en exception. A gir startforespørsel; B låser stopp frem til omstart. |
| 5. Feilgrensen | Bevar første årsak, latch stopp, forsøk én stoppoperasjon, bevar eventuell sekundær feil og logg etterpå. Fortell hvorfor en exception i lys-tasken må varsles eksplisitt til Main. |
| 6. Oppstart | Sett FULL_OFF før motorstyringen vekkes. Ved ukjent registermodus adresseres hver kanal separat. OLED er valgfri: første feil deaktiverer den, slik at skjermarbeid ikke skaper en forsøksstorm. |
| 7. Lys | Én task eier GPIO. Protected object deler bare små statusverdier. 50 ms er en ønsket periode, ikke et bevist responstidskrav. Registertest beviser ikke at monterte dioder lyser. |
| 8. Skanning | Vi søker første tilstrekkelige kandidat, høyst fire sideposisjoner. Forklar 26 cm breddekrav, 12° og hvorfor omtrent 124,4 cm kreves. Faste sidesensorer måles mens frontservoen sentreres. Alle filterprøver beholdes. Evidensen må være fersk helt frem til kjøring. |
| 9. Tid | Tegn kjeden til neste relevante måling, sensorlatens, beslutning og stopp. 20 ms er parameter per I2C-kall. Ved fallback gir åtte kall 160 ms i budsjetter, med tillegg. Nominelt 130 ms frontbesøk er ingen maksimal fysisk reaksjonstid. |
| 10. Matematikk | Forklar `d = v*t + v²/(2*a) + margin`. Fart og bremsing må måles; PWM er ikke fart. Sensorenes repeterbarhet og bias er forskjellige egenskaper. |
| 11. Evidens | 2599 Ada-kontrollpunkter er ikke 2599 kjøreforsøk. Vis ett injisert feilscenario og én test som avviser en bevisst kildemutasjon. SPARK gjelder faktisk lyspolicy; resten av bilen og tidsegenskapene er ikke formelt bevist. |
| 12. Avslutning | Oppsummer de konkrete forbedringene og vis siste kravstatus. Før fysisk akseptanse gjenstår forsyning, sensorer/I2C, hjulfortegn, skannetid, fart, stopp og sammenhengende løype. |

## Spørsmål gruppen bør kunne svare på

**Hvorfor bruker dere ikke exceptions for hver ugyldig sensorverdi?**
Manglende/ugyldig ekko er en forventet mulighet i målingen. Det gir ukjent
avstand og normal stoppflyt. Exceptions brukes for feil som må avbryte
aktiviteten og låse kjøringen, for eksempel feil på motorbussen.

**Hva beviser protected object, testene og SPARK hver for seg?**
Protected object ordner synkronisert tilgang til lysstatus. Tester viser
observerbar oppførsel i utvalgte scenarier og fakes. SPARK-beviset viser
lyspolicyens spesifiserte logiske egenskaper under bevisforutsetningene.
Ingen av dem alene beviser at en fysisk motor eller LED virker.

**Hvorfor ikke dele alt i flere tasks?**
Flere tasks krever en tydelig eier av I2C og ultralyd, tidsstemplede data,
prioriterte stopp og en analyse av køer og blokkering. Vi har valgt én
kontrolleier og en uavhengig lys-task. Det faktiske oppsettet skal analyseres
før videre oppdeling, slik at tasking løser et konkret problem.

**Er dette et bevist sanntidssystem?**
Nei. Det finnes tidsparametre og en analysemetode, men fysisk deadline,
WCET og stopplengde mangler fortsatt tilstrekkelige måledata. Forklar hva
som skal måles og hvordan `R <= D` og stoppmodellen brukes etterpå.

**Er skanningen matematisk optimal?**
Den minimerer unødvendig arbeid gjennom tidlig retur og har et begrenset
søkeomfang. Med kjente sannsynligheter/kostnader kan kandidater ordnes etter
`p/c`; størst sideklaring er foreløpig en heuristikk. Vi påstår ikke globalt
korteste eller sikreste rute. Sparsomme stråler må vurderes mot faktisk bane.

**Hvorfor er en kvittert stopp ikke nok?**
Kvitteringen viser at busskommandoen ble akseptert. Den måler ikke hjulene,
bremselengden eller en fastlåst driver. Ved bussfeil kan programvarestopp
svikte; fysisk motorfrakobling må være mulig under forsøkene.

Før fremføring skal hvert gruppemedlem kunne følge én normal kjøresekvens
og én feil fra `Main` gjennom pakkene og tilbake til motorstopp. Fyll inn
faktiske egne bidrag og erfaringer etter gjennomgangen.
