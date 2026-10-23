# Sensorstudie 23.10.2026

Eksisterende Overleaf-rapport er utvidet med `sensor-study-2026-10-23.tex` (avsnitt 7.6), metodefigur, elektrisk beregningsmodell, statistikk, forsøksresultater og tydelige begrensninger. Begge seriers rådata og analyser følger Overleaf-prosjektet som `sensor-run-01.csv`, `sensor-run-02.csv` og tilhørende JSON-analyser. I Git finnes originalene under `evidence/2026-10-23-sensors/`. `SENSORPROTOKOLL.md` gir reproduksjon og videre fysiske kontroller.

640 stasjonære avlesninger er samlet med motorstrøm frakoblet. Venstre kanal er fortsatt ustabil. 1753 Ada-kontroller og 16 Python-enhetstester består; dette er programtester, ikke 1769 fysiske forsøk. Ingen ny sving- eller gulvkjøring er validert. Endelig faktisk Overleaf-/PDF-kontroll står i `VALIDERING.md`. Micro:biten står med separat stoppende diagnostikk V2 etter testen.

Oppdateringene nedenfor er bevart som historikk fra forrige økt.

---

# Oppdatering 23.10.2026

Denne pakken viderefører rapporten hentet fra det eksisterende Overleaf-prosjektet. Historisk tekst og kode fra 21.10 er beholdt. Daterte resultater og endringer finnes i `development-2026-10-23.tex` og nye kildekopier i `code/2026-10-23/`. Disse delene er kompilert lokalt og i eksisterende Overleaf-prosjekt. Siste Overleaf-bygg ga 42 sider, 0 feil og 0 ordinære advarsler. Se `VALIDERING.md` for avgrensninger.

Den aktive implementasjonen er fortsatt sekvensiell. Bruk dagens hovedrepo og den kumulative driverpatchen `patches/ada-drivers-2026-10-23.patch` for firmwarebygg. Historiske opplysninger nedenfor gjelder pakken fra 21.10.

---

# ADAptive per 21.10.2026

Last opp hele ZIP-filen som et nytt prosjekt i Overleaf. Velg `main.tex` som hovedfil og **pdfLaTeX** som kompilator. Prosjektet bruker BibTeX via `natbib`; Overleaf kjører bibliografiverktøyet automatisk. Ingen shell escape, ekstern kodefremhever eller ekstra skrifter er nødvendig.

## Redigering

- `main.tex`: hele rapportteksten, formatering, figuren og vedleggsstrukturen.
- `bibliography.bib`: redigerbar bibliografi.
- `code/main.adb`: uendret applikasjon fra Git-revisjon `ee6df67ab8ebec4e309195324f941b61602a1a36`.
- `code/ada-drivers-2026-10-21-raw.patch`: driverpatch fra samme revisjon.
- `code/drivers/`: kopier av relevante lokale drivere, med lokale tilpasninger. Ikke et komplett firmwareprosjekt.
- `dokumentasjon/utviklingslogg-2026-10-21.md`: uendret logg hentet fra revisjonen.
- `dokumentasjon/kildekontroll.json`: kontrollert revisjon, arbeidsstatus og driverdiff.
- `grunnlag/`: bevart originalrapport, tekstuttrekk og tidligere rapportarbeid fra 8.10.
- `INNHOLDSKONTROLL.md`: sammenheng mellom originalinnhold og oppdatert rapport.

Alle manglende opplysninger er synlig merket **TODO**. Fyll dem med faktiske opplysninger og måledata. Ikke fjern forbehold om tester før testene er dokumentert. Navn og studentnummer er videreført som skrevet i originalrapporten.

## Rapportens faglige status

Dette er en rapport om fremdrift per 21.10.2026. Den følger originalens ti kapitler, med IMRaD-funksjonene forklart i leserveiledningen. IRTS-malens rapportklasse, forside, sammendrag, innhold, bibliografi og kodevedlegg er videreført og tilpasset norsk. Eksempelreferanser, MATLAB-stil og tomme dobbeltsider fra malen er utelatt. Logo og grafikk er hentet fra originalrapporten.

Dagens applikasjon har en sekvensiell FSM med 60 tilstandssteg, aktiv fremoverpuls og rotasjon. Sensor-, kontroll-, motor- og sikkerhetstasks er forslag. `Reverse_Drive` utfører foreløpig bare stopp. OLED-avstandsfunksjonen finnes, men kalles ikke av den aktive FSM-en. LED viser skannevalget og er ikke en kontinuerlig kjøretøystatus.

Byggverdiene og de fysiske observasjonene er hentet fra utviklingsloggen. Ingen nye firmwarebygg, flashing eller maskinvaretester er gjennomført ved rapportoppdateringen. WCET, deadlines og kollisjonsunngåelse er ikke verifisert. Verktøykjedens GNATprove-avhengighet er ikke bevis på at SPARK-analyse er gjennomført.

## Lokal kompilering

Med en vanlig TeX-installasjon:

```text
latexmk -pdf main.tex
```

Alternativt:

```text
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex
```

PDF-forhåndsvisningen er kompilert fra prosjektet med Tectonic. Kilden er også kontrollert med kompilatoren i Codex sin LaTeX-editor. En faktisk opplasting til Overleaf er ikke gjennomført.

`main.tex` må ligge sammen med bibliografien og resten av prosjektmappene for å gi hele rapporten. Rapportpakken er en dokumentasjonspakke; bygging av kjøretøyets firmware krever det opprinnelige Git-repoet og undermodulen.

## Før innlevering

Fullfør KI-deklarasjon, arbeidsfordeling, maskinvareidentifikasjon, koblingsskjema, rå bygglogger, advarseltekst og systematiske testprotokoller. Fastsett målbare tidskrav og utfør en analyse som svarer til den faktiske programarkitekturen. Oversikten over åpne punkter finnes også i siste vedlegg i PDF-en.
