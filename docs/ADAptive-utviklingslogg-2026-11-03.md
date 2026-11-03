# ADAptive – programvarearbeid 3.11.2026

Denne økten følger `ADAptive-Work-kun-programvare-2026-11-03.md`.
Fysiske akseptansekrav: **ikke testet**. Micro:biten er ikke kontaktet via
USB, serieport, debugprobe, GPIO eller I²C. Ingen flash-/reset-/halt-/resume-
kommandoer er kjørt, og ingen fysiske brukerhandlinger er etterspurt.

## Arbeidsgrunnlag og sikkerhetskopier

Faktisk arbeidskopi er `/home/kidi970/Documents/ChatGPT/ADAptive`, på
`codex/pi-integration-exceptions-2026-11-02`, utgangspunkt `2f338d4`.
`ADAptive-bench` inneholder Python-miljø og eksisterende firmwarebackuper,
men ingen kildecheckout. Backupene der er urørte.

Før endringer ble 3189 kildefiler arkivert med hashmanifest, eksisterende
Git-status og driverdiff i `build/software-only-2026-11-03/`. Eksisterende
`build/main.elf`, `.hex` og `.bin` ble kopiert til en separat lokal mappe
før nye bygg. Dette er ikke en ny readback av kortet.

ZIP-pakken ble mottatt under arbeidet. SHA-256:
`e8a063d6aa58a21919bbbbf2cdfce1e573a3025af165fbe973997de8c49c53ff`.
CRC og alle oppførte filhashverdier stemte. Pakkens base er `cf1178c`,
mens den lokale grenen allerede inneholdt nyere novemberarbeid.
Tretten nye overlayfiler ble importert; den gamle testkjøreren ble flettet
inn i den nyere lokale kjøreren. Driverpatchen er byteidentisk med den
allerede anvendte patchen og ble ikke anvendt en gang til. Originalpakke,
binærer og identifikatorer holdes i ignorert lokal byggmappe.

## Endringer

- Innlemmet og gjennomgått USB- og komponentprogrammene, benkmodellen,
  OLED-koderen, OLED-adapteren og standalone-verktøyet.
- Erstattet uavgrenset UART-sending med en logger på maksimalt 160 tegn
  pluss CR/LF, en felles 30 ms linjefrist og 100000 pollingforsøk.
  Feil deaktiverer loggeren; fristen er ingen målt WCET.
- Fjernet hovedprogrammets unødvendige DFR0548-helperavhengighet ved å
  kode de identiske PWM-800-registermønstrene direkte. Unngått sammenføying
  av begge ubundne exception-strenger i feilhåndtereren.
- USB-profilen bruker en liten adapter for innebygd lys/A/B. En reell
  transitiv TWI-avhengighet ble fjernet uten å lempe symbolforbudet.
- OLED-benkadapteren innkapsler unntak fra bussinitialisering, probing og
  skriving. Ingen skjermtilgjengelighet betyr ikke defekt micro:bit.
- Benkmodellen har eksplisitt gyldighetsandel og avviser NaN/inf og ugyldige
  elektriske/statistiske parametre. Tekstbuffergrenser testes.
- Implementert rene SI-modeller for stopplengde, ferskhet, statistikk,
  kalibreringsstyrt sensoroffset/vinkeltransformasjon og samplet åpning.
  Offline 1P/5P/7P-valg rangerer bare allerede tillatte kandidater.
  Ny beslutnings-ID alene kan ikke gjenbruke gamle observasjoner.
- Capture-verktøy krever eksplisitt forventet bildehash og probeidentitet.
  Flash krever kontrollsummert dobbeltbackup av full flash og UICR.
  Feil readback gir ikke godkjent status eller etterfølgende kjørereset.
  Testene bruker syntetiske filer og falske backender.
- Ny statisk ELF/HEX-/stack-/binderkontroll og historisk avspilling gjennom
  faktisk Ada-filter. Test-, verktøy- og dokumenthash inngår i sluttkontrollen.

## Resultater fra denne økten

- Native Ada: **3716 kontrollpunkter bestått i 14 suiter**.
- Python: **114 tester bestått**.
- Negativ kontroll: **20 mutasjoner avvist**, inklusive én SPARK-kontrakt.
- Avgrenset SPARK-bevis for faktisk lyspolicy: bestått.
- Krysskompilering: **seks ARM-prosjekter bestått** (hovedprogram, sensor V2,
  GPIO V3, lysdiagnostikk og begge standalone-programmer).
- Statisk filkontroll: ELF-/HEX-konsistens og strengt USB-avhengighetsforbud.
  Fire utelatte paddingbyte i hovedbildets PT_LOAD var et justeringsgap,
  ikke tapt allokert programdata. Ekte manglende programbyte avvises.
- Hovedbyggets største rapporterte enkeltfunksjonsramme: 704 B; seks rammer
  er dynamiske. Dette er ikke samlet stackforbruk eller målmaskinens WCET.

Historisk avspilling: tre oktoberfiler à 320 råprøver gir 104/104 aksepterte
komplette filtertripler per fil. Sensorstrøm-av-loggen gir 0/104, med
0/320 gyldige råprøver. Ufullstendige haler oppgis. Dette er analyse av
eldre data, ikke nye målinger eller en timed simulering av bilen.
`legacy_cm` er eksplisitt brukt uten kalibreringskorreksjon.

Statisk stackanalyse skiller 16 KB primærstack, 2 KB interruptstack,
512 B standard sekundærstack og tasklagring. Enkeltrammer og cachede
filer gir ingen samlet øvre stackgrense. Ingen stackmaksimum er målt.

## Begrensninger og levering

Produksjonens terskler og 65/500 ms sensor-/servotider er ikke svekket.
PWM er ikke behandlet som fart. Servokommando 34/134 er ikke antatt å være
fysiske ±90 grader. Strålebredde, vinkelkalibrering, full svingbane,
retardasjon og maksimal latens er ikke fysisk verifisert. Modellen er
et offline tillegg og gir ingen ny motorautorisasjon i produksjonskoden.

Komponentprofilen bruker en annen benktopologi (P0/P9/P16/P3) enn bilens
lysplan (P0/P12/P16). Ingen kobling eller fysisk test er utført.
Eldre aktive `bench_capture.py` er ikke importert eller kjørt.

Lokal rapport og presentasjon oppdateres og kompileres. Overleaf-nettprosjektet
kan ikke åpnes fordi lokal nettlesertilgang er deaktivert i Work; **nettprosjektet
er ikke oppdatert**. Et integrert LaTeX-kapittel og komplett lokal Overleaf-pakke
leveres. Historiske forsøk og gruppearbeid er bevart. GitHub-publisering gjøres
på eksisterende arbeidsgren, uten force-push eller merge til main; faktisk
commit/push-status oppgis i sluttsvaret.

Prioritert videre programvareoppgave: avgrens hele hovedprogrammets oppstart,
inkludert elaborering, og analyser komplette kallkjeder og sekundærstack.
