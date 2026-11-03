# Rapport og presentasjon

Gjeldende hovedrapport er `main.tex`, med tekst i `report-body.tex`,
`sections/` og det integrerbare tillegget `software-only-2026-11-03.tex`.
`presentation.tex` er oppdatert tilsvarende. Nye resultater skiller native
programtester, simulering, historisk avspilling, firmwarebygg og statisk
filkontroll. Maskinvareavhengige krav er **ikke testet** i denne økten.

## Leveranse 3. november

Etter full kontroll ligger følgende under `../build/deliverables/`:

- `ADAptive-rapport-programvare-2026-11-03.pdf`
- `ADAptive-presentasjon-programvare-2026-11-03.pdf`
- `ADAptive-Overleaf-programvare-2026-11-03.zip`
- `delivery-programvare-2026-11-03.json` med faktiske sidetall, SHA-256 og resultater.

ZIP-pakken inneholder LaTeX, bibliografi, figurer, aktuell kildekodekopi og
historiske grunnlagsfiler/evidens. ZIP-CRC og alle oppføringer kontrolleres.
Hovedfil for rapport er `main.tex`, for presentasjon `presentation.tex`, med
pdfLaTeX og BibTeX. Begge kompileres lokalt før levering.

**Overleaf-nettprosjektet er ikke oppdatert.** Lokal nettlesertilgang er
deaktivert i Work. Den lokale pakken er integrerbar i det eksisterende
prosjektet uten å omskrive historiske forsøksresultater eller gruppearbeid.
Ingen bestemt sidetelling er antatt; se manifestet fra faktisk kompilering.

## Oppdatere og bygge uten maskinvare

Fra Git-repoets rot:

```sh
python3 tools/sync_report_sources.py
python3 tools/check_project.py --full --out build/software-only-2026-11-03/verified
python3 tools/package_delivery.py --tag programvare-2026-11-03 --verification build/software-only-2026-11-03/verified/verification.json
```

Kommandoene åpner ikke USB, serieport, debugprobe, GPIO eller I²C. ARM-bilder
bygges og inspiseres som filer. Den genererte `code/current/` er en bytekopi
av aktuelle Ada-enheter, standalone-programmer, GPR-filer og driverpatch.
`--check` avviser avvik. Resultatene er bundet til kilde-, test-, verktøy- og
dokumenthash. Firmwarebygg krever Git-repo, låst undermodul og anvendt patch;
rapportpakken alene erstatter ikke et komplett firmware-checkout.

## Historikk og åpne punkter

`development-history.tex` bevarer den eldre hovedkilden uendret. Daterte
seksjoner, tidligere leveranser og originale rådata beholdes. Kapitlet om
resultater fra 2. november er merket som baseline; nye resultater fra
3. november er skilt ut. Pensum/sensurveiledning, gruppens egen arbeidsfordeling
og KI-deklarasjon er fortsatt åpne punkter som ikke fylles med antakelser.
Full autonom kjøring, sensorstabilitet, oppstart på kortet, stopplengde,
deadlines og faktisk stackmaksimum er ikke godkjent av programvaretestene.
