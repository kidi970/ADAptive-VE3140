# Bevaring og oppdatering av originalinnhold

Kilde: `ADAptive Rapport (1).docx`, 144 144 byte. Originalen er ikke endret. En byteidentisk kopi ligger i `grunnlag/`, sammen med tekstuttrekket `original-docx.txt`. Utkastnotater og tomme overskrifter er dermed også tilgjengelige i opprinnelig form.

## Faktisk innhold

| Originalt innhold | Bevaring i ny rapport |
|---|---|
| Innleveringsoppgave, VE3140-1 26H, Intelligente sanntidssystemer | Forside med samme emne og semester |
| Dato 07.10.2026 | Beholdt som originaldato; rapportstatus oppdatert til 21.10.2026 |
| 266584 – Nicolay Olafsen | Forside og kapittel 8, uendret navn og studentnummer |
| 228979 – Jacob Hellumstand Utengen | Forside og kapittel 8, uendret navn og studentnummer |
| ADAptive Real-Time System | Beholdt tittel på forsiden |
| 1.1 Oppgavebeskrivelse, tre faktiske avsnitt | Videreført i kapittel 1.1; taskingformuleringen er uttrykkelig merket som prosjektmål |
| 1.2 Problemstilling | Videreført ordrett i kursiv i kapittel 1.2 |
| 1.3 Mål og avgrensninger, to avsnitt | Videreført i kapittel 1.3 og avgrenset mot dagens kildekode |
| FR1–FR6 | Alle seks krav videreført med opprinnelig ordlyd i tabell 2.1 |
| RT1–RT3 | Alle tre krav videreført med opprinnelig ordlyd i tabell 2.2 |
| SR1–SR4 | Alle fire krav videreført med opprinnelig ordlyd i tabell 2.3 |
| Logo og lilla forsidegrafikk | Begge bildefilene bevart i figures/ og brukt på forsiden |

Det er ikke fjernet faktiske resultater fra originalrapporten: den inneholder hovedsakelig innledning, krav, disposisjon og skriveanvisninger, og ingen utfylte kvantitative testresultater eller tidsmålinger.

## Disposisjon og opprinnelige skriveanvisninger

| Opprinnelig del | Videreføring |
|---|---|
| 1.4 KI-deklarasjon, opprinnelig tom | Konkret deklarasjon for denne rapportoppdateringen; øvrig KI-bruk står som TODO |
| 3.1–3.6 Teori, opprinnelig tomme | Utfylt med sanntid, Ada/tasking, micro:bit V2, Mecanum, sensorprinsipp og RTA |
| 4.1 Sensorer → sensoravlesning → beslutning → motorstyring → bil | Bevart i tekst og oppdatert systemfigur |
| 4.2 Liste over micro:bit, bil, motorer, driver, sensorer og annen maskinvare | Tabell 4.1, med uavklarte fysiske detaljer merket |
| 4.3 Sensor Task → sensordata → Control Task → ønsket bevegelse → Motor Task → motorer | Bevart som opprinnelig foreslått arkitektur i 4.4; 4.3 beskriver dagens faktiske sekvensielle flyt |
| 4.4 Forslag til Sensor_task, Control_task, Motor_task og Safety_task | Alle fire forslag og deres opprinnelige ansvar er beholdt i tabell 4.2 |
| 4.5 Kjøring → sensorer → hinder? → unnamanøver → området fritt? → normal kjøring | Bevart i kontrollstrategien; konkretisert med faktisk FSM-tabell |
| 4.6 Periodisitet, kritikalitet, prioritet, deadlines og rask sensorreaksjon | Behandlet i 4.6 og kapittel 6, uten å finne på tidsverdier |
| 5.1–5.5 Implementasjon, opprinnelig tomme | Motor, Mecanum, sensor, taskstatus og integrasjon er utfylt fra kildekoden |
| 6.1–6.5 Real-Time Analyse, opprinnelig tomme | Beholdt under norsk kapitteltittel Sanntidsanalyse. Skrivefeilen «Taks» er rettet til «Oppgaver» |
| 7.1–7.4 Tester & Resultater, opprinnelig tomme | Rapporterende resultattabeller og separat plan for fremtidige funksjons- og tidsmålinger |
| Kapittel 8: planlegging, arbeidsfordeling, GitHub, samarbeid, utfordringer | Behandlet med dokumentert fremdrift; ubekreftet arbeidsfordeling er TODO |
| Kapittel 9: vurdering av resultater, begrensninger og forbedringer | Utfylt med konkrete funn og begrensninger |
| Kapittel 10: besvare problemstilling og vurdere krav | Konklusjonen gir delvis svar og fastslår at tidskravene ennå ikke er verifisert |

Originalens innholdsfortegnelse manglet kapittel 5 som egen oppføring, selv om kapitlet fantes i teksten. Den nye innholdsfortegnelsen genereres automatisk fra alle ti kapitlene. Sidetall og typografi er oppdatert; utkastets tomme linjer og utdaterte manuelle sidetall er ikke gjenskapt.

## IMRaD og IRTS-malen

- Innledning: kapittel 1.
- Metodegrunnlag: krav, teori, systemdesign, implementasjon og analysemetode i kapittel 2–6.
- Resultater: kapittel 7; planlagte tester er skilt fra rapporterte resultater.
- Prosessevaluering: kapittel 8, slik oppgaven ber om.
- Diskusjon og konklusjon: kapittel 9–10.
- Referanser og vesentlig Ada-kode: bibliografi og vedlegg A–C.

IRTS-malen er brukt som struktur- og formateringsreferanse. Malens ferdigutfylte eksempelår, generiske fakultetslinjer, MATLAB-eksempel, Einstein/Dirac-referanser og UiA-metadata er ikke videreført som fakta om ADAptive.

## Viktigste faglige avklaringer

1. `main.adb` fra ee6df67 er inspisert; rikere funksjonsbeskrivelse er nå støttet av kode, ikke bare tidligere omtale.
2. Dagens FSM er sekvensiell og stopper etter 60 tilstandssteg. Taskarkitekturen er fortsatt et forslag.
3. Fremoverkommandoen er aktiv i Forward-grenen, til tross for en eldre kommentar om deaktivert fremdrift.
4. `Reverse_Drive` er reservert og stopper; den er ikke en implementert ryggemanøver.
5. Filteret heter Median, men beregner laveste samsvarende parverdi, ikke medianen.
6. Verify tillater 400 cm i sin betingelse, mens filteret begrenser effektive verdier til 200 cm.
7. `Show_Front` er definert, men ikke kalt av den aktive FSM-en. OLED-tilstand oppdateres.
8. LED viser skannevalget; symbolet oppdateres ikke nødvendigvis ved hver senere stopp.
9. Driverpatchen inneholder exit fra timeout-løkkene. Det tidligere identifiserte kodeproblemet beskrives derfor som rettet i den lokale tilpasningen, uten å påstå målt WCET.
10. Byggverdier og fysisk LED-test er rapportert i utviklingsloggen. Full autonom gulvkjøring, WCET, deadlines og stopplengde er ikke ferdig verifisert.
