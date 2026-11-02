# Rapport og presentasjon

Gjeldende hovedrapport er `main.tex`, med tekst i `report-body.tex` og
`sections/`. Hovedteksten er 17 sider, referanser én side, og PDF-en 47 sider
med forside, sammendrag/innhold og alle applikasjonens Ada-enheter i vedlegg.
`presentation.tex` gir 12 lysbilder. [Manus og faglige kontrollspørsmål](PRESENTASJONSMANUS.md) følger. Kildene beskriver dagens implementasjon
og skiller programtester, fysisk evidens og avgrenset formelt bevis.

## Ferdig leveranse

Etter full kontroll ligger følgende under `../build/deliverables/`:

- `ADAptive-rapport-kodekontroll-2026-11-02.pdf`
- `ADAptive-presentasjon-kodekontroll-2026-11-02.pdf`
- `ADAptive-Overleaf-kodekontroll-2026-11-02.zip`
- `delivery-kodekontroll-2026-11-02.json` med SHA-256 og kontrollresultater.

ZIP-pakken inneholder LaTeX, bibliografi, figurer, gjeldende kodekopi og
historiske grunnlagsfiler/evidens. ZIP-CRC og alle filer sammenlignes med
kildene. Last opp pakken til Overleaf, velg **main.tex** og **pdfLaTeX**.
For presentasjonen velges **presentation.tex**. BibTeX kjøres automatisk.
Overleaf-prosjektet er ikke endret i denne gjennomgangen.

## Oppdatere og bygge

Fra Git-repoets rot:

```sh
python3 tools/sync_report_sources.py
python3 tools/check_project.py --full
python3 tools/package_delivery.py
```

Den genererte `code/current/` kopierer aktiv kode byte for byte og har et
SHA-256-manifest. `--check` avviser en utdatert kopi. Bygglogger ligger under
`../build/readiness-review/`. Disse kommandoene berører ikke bilen.
Rapportpakken alene er ikke et komplett ARM-checkout; firmwarebygg krever
Git-repoet, låst undermodul og driverpatch.

## Historikk og åpne punkter

`development-history.tex` er en identisk kopi av forrige 60-sidersrapports
hovedkilde. Daterte seksjoner og kodekopier er bevart og brukes bare som
historikk. Tidligere PDF-er beholdes i `../build/deliverables/`.
`grunnlag/` bevarer originalrapport og oppgavetekst; `INNHOLDSKONTROLL.md`
beskriver tidligere innholdsbevaring. Originale rådata ligger i `evidence/`.

Se [klar-for-benk](KLAR-FOR-BENK.md) for fysisk testrekkefølge og det som
fortsatt trenger gruppens egne opplysninger. 2599 Ada-kontroller, 40
Python-tester og SPARK-bevis for lyspolicy er programvareevidens. Full autonom
kjøring og deadlines er ikke fysisk verifisert. Synlige TODO-er gjelder
målinger, arbeidsfordeling og KI-bruk; de skal ikke erstattes med antakelser.
