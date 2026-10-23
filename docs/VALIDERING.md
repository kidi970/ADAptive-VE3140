# Oppfølging av pinnebekreftelse 23.10.2026

Bruker bekreftet at bare venstre ultralydsensor bruker P2/P14. Avsnitt 7.6, sensorlogg og protokoll er presisert på dette grunnlaget; firmware, matematikk og rådata er uendret. Ingen nye fysiske forsøk eller programtester er kjørt i denne dokumentasjonsoppfølgingen.

Faktisk Overleaf-kompilering: 45 sider, 0 feil, 0 ordinære advarsler, 2 eksisterende underfull-meldinger og ingen overfull-meldinger. De endrede avsnittene på PDF-side 22 og 24 er visuelt kontrollert. Ingen `??`-henvisninger, og alle 23 skrifter er innebygd. PDF SHA-256: `64d0d63c82ef6ad50eaf51d1310ed9956ffc7c0ce1330d8114006cf1ac8f5f19`.

Tidligere test- og rapportkontroll er bevart nedenfor.

---

# Kontroll av sensorstudien 23.10.2026

Eksisterende Overleaf-prosjekt er oppdatert og faktisk kompilert etter sensorøkten. Sammendraget viser både tidligere avsnitt 7.5 og ny sensorstudie i avsnitt 7.6. Historisk tekst og kode er bevart.

- **45 PDF-sider**, 0 feil, 0 ordinære advarsler. To underfull-meldinger gjelder bevart tekst/bibliografi; ingen overfull-meldinger.
- Ny metodefigur, koblingstabell, forsøksresultater og modeller er visuelt kontrollert på PDF-side 22–24. Alle sider er gjennomgått i oversikt; sammendrag og innhold er kontrollert separat.
- Ingen `??`-henvisninger i tekstuttrekket. Alle 23 brukte skrifter er innebygd.
- PDF lastet ned fra faktisk Overleaf-bygg, SHA-256 `528cf101ef304c538810acefd724e1c584b04ff43410b6558e0a589e7ce5413b`.
- Rådata fra begge serier, analyser, `SENSORPROTOKOLL.md` og sensorloggen følger rapportprosjektet. Originale seriellogger og kildeøyeblikksbilder ligger i Git-repoets evidensmappe.
- 640 fysiske stasjonære avlesninger; venstre kanal fortsatt ustabil. Ingen nye motor-, gulv- eller belastningsforsøk. Ingen referanseavstander er oppdiktet.
- 1753 native Ada-kontroller og 16 Python-enhetstester besto. Diagnostikk og navigasjonsfirmware bygger. Micro:biten står med stasjonær diagnostikk V2.

Filmanifestet gjelder den eksporterte Overleaf-pakken; Git-repoets komplette `docs/` inneholder også flere utviklingsfiler og evidens. Tidligere kontroller følger som historikk nedenfor.

---

# Kontroll 23.10.2026

Den oppdaterte rapporten kompilerte både lokalt og i det eksisterende Overleaf-prosjektet etter siste retting.

- Overleaf: 0 feil, 0 ordinære advarsler, 2 underfull-typesettingsmeldinger i bevart tekst/bibliografi. Ingen overfull-meldinger etter siste retting.
- 42 PDF-sider. Alle sider gjennomgått i oversikter; endrede sider kontrollert i full størrelse. Ingen tomme sider eller uavklarte ??-henvisninger i tekstkontrollen.
- Alle brukte PDF-skrifter er innebygd. FSM-figur og testtabell er kontrollert.
- PDF er lastet ned fra den faktiske Overleaf-kompileringen, ikke bare fra en lokal kompilator.
- PDF SHA-256: 037b72592e198fd086fb02d7e537c67039c96adfc1bf0302afb1b5fd13adad4b.
- Historisk tekst og kode fra 21.10 er beholdt. Oppdateringen gjelder datert avsnitt 7.5 og nye kodevedlegg; øvrig tekst omtales uttrykkelig som historisk grunnlag i sammendraget.
- ZIP-integritet og filmanifest kontrolleres ved pakking. Full flashkopi og personlige arbeidsbackuper følger ikke rapportpakken.

Fysiske benketester og videre begrensninger er dokumentert i `dokumentasjon/utviklingslogg-2026-10-23.md`. Dokumentkontroll beviser ikke oppfylte sanntidskrav eller autonom gulvkjøring.

---

Historisk kontroll av pakken fra 21.10 følger nedenfor.

# Kontroll av rapportpakken 21.10.2026

## Innhold

- Alle 13 opprinnelige krav (FR1–FR6, RT1–RT3 og SR1–SR4) er kontrollert mot Word-dokumentet og videreført med opprinnelig ordlyd.
- De seks utfylte faglige avsnittene i originalens kapittel 1 er kontrollert og bevart, inkludert problemstillingen.
- Den arkiverte originalrapporten er byteidentisk med vedlegget.
- Alle ti opprinnelige hovedkapitler er videreført. Tomme overskrifter og utkastnotater er behandlet i INNHOLDSKONTROLL.md.
- Dagens applikasjonskode er hentet fra Git-objektet ee6df67ab8ebec4e309195324f941b61602a1a36. Driverkopier er fanget fra lokal undermodul med de to dokumenterte tilpasningene.
- Det er ikke kjørt nye firmwarebygg eller fysiske tester ved rapportoppdateringen. Rapporterte bygg- og testresultater er uttrykkelig kildeangitt.

## LaTeX og PDF

- Siste main.tex kompilerer med Tectonic og med den innebygde LaTeX-editorens kompilator.
- 36 PDF-sider totalt: 4 sider forside/sammendrag/innhold, 16 sider hovedtekst, 2 sider referanser og 14 sider vedlegg.
- 16 brukte bibliografireferanser, uten manglende sitatnøkler eller udefinerte kryssreferanser.
- Ingen duplikate etiketter eller overfulle tekstbokser i siste bygg.
- Ingen tomme sider eller erstatningstegn i tekstuttrekket.
- Alle 21 brukte skrifter er innebygd i PDF-en.
- Alle 36 sider er rendret med Poppler og visuelt gjennomgått. Figur, tabeller, sidebrudd og kodevedlegg er kontrollert. Enkelte underfull-advarsler gjelder ordmellomrom; de gir ikke innhold utenfor margene.
- Faktisk opplasting og kompilering i Overleaf er ikke gjennomført. Prosjektet bruker standardpakker for pdfLaTeX og BibTeX.

## Arkiv

ZIP-en bygges med main.tex i roten og inkluderer redigerbare kilder, bibliografi, kode, logg, malgrunnlag og originalrapport. SHA256SUMS.txt angir filkontrollsummer. Arkivet kontrolleres med ZipFile.testzip(), og alle oppføringer sammenlignes med kildefilene etter pakking.

Denne kontrollen gjelder dokumentet og kildeproveniensen. Den erstatter ikke kjøretøyets funksjons- og sanntidstester.
