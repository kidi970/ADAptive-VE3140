# ADAptive – Raspberry Pi og exceptions, 2. november 2026

## Utgangspunkt og avgrensning

Den tomme prosjektmappen på Pi-en er fylt med eksisterende Git-repo fra
`fix/startup-navigation-2026-10-23`, grunnrevisjon
`cf1178c8241154e5444b5225ea498ef9b05363ab`. Arbeidet ligger på egen gren
`codex/pi-integration-exceptions-2026-11-02`. Ingen tidligere lokal kode fantes
i denne mappen. Eldre arbeidskopier på Windows er ikke tilgjengelige her.

Maskinen er Raspberry Pi 5, Debian 13, aarch64. Ingen micro:bit ble funnet på
USB. Ingen firmware er flashet, ingen motor-/GPIO-kommandoer er utført fra
Pi-en, og ingen ny fysisk test er gjennomført. Eksisterende RFID-tjenester
på Pi-en er ikke omkonfigurert. Selve `ISforelesninger.pdf`, gjeldende
sensurveiledning og leveringsfrist mangler fortsatt.

## Kodeendringer

- `Adaptive_Errors` gir navngitte exceptions for motorbuss, ufullført
  oppstart, servovinkel, latchet stopp og registrering av stoppknapp.
  Standardexceptions klassifiseres separat.
- Den generiske `Adaptive_Fault_Handler` bevarer første årsak, setter
  stoppflagget, forsøker stopp én gang og logger etterpå. Sekundær stoppfeil
  og loggerfeil blir synlige i status. En feiltilstand kan ikke resettes
  gjennom denne pakken. Hovedprogram og diagnostikk V2 bruker samme grense.
- Motor-I2C logger adresse, register og transportstatus. Drive avvises før
  ferdig initialisering og etter latchet stopp. Stopp kontrolleres også
  etter motorsending, fordi knappavbruddet kan komme mens sendingen pågår.
- Oppstart slår av åtte motor-PWM-kanaler før PCA9685 vekkes. Ved ukjent
  auto-increment brukes individuelle FULL_OFF-skrivinger. Normal stopp
  bruker burst når konfigurasjonen er kjent. Ny statusvariabel skiller
  anerkjent stoppkommando fra mulig fortsatt aktiv bevegelseskommando.
- Motor/OLED deler bussinitialiseringen. OLED har eksplisitt 20 ms
  timeoutparameter per skriving. Den kumulative driverpatchen fra 23.10 er
  lagt på som dokumentert; ingen ny undermodulrevisjon er opprettet.
- `tools/pi_link.py` har USB-status og tidsavgrenset passiv logging. Det
  implementerer ingen flashing, reset, fjernkjøring eller GPIO-styring.
- GitHub Actions-jobben får driverpatchen og native tester før ARM-bygg.
  Den endrede workflowen er syntakskontrollert, men er ikke kjørt i GitHub
  Actions i denne økten. Lokale tester og bygg er kjørt på Pi-en.

Dette er et testet programvaregrunnlag. Det er **ikke** dokumentasjon på at
den tidligere fysiske I2C-feilen er løst, at hjulene stopper når I2C feiler,
eller at den autonome gulvtesten er bestått. Løsningen erstatter heller ikke
elektrisk nødstopp eller en last-chance-handler ved feil før hovedprogrammet.
Feilhandleren har én sekvensiell eier; den er ikke en ferdig flertrådet supervisor.

## Faktisk verifikasjon

| Kontroll | Resultat |
|---|---|
| Eksisterende Ada policy/FSM | 1729 kontroller bestått |
| Eksisterende Ada avstandsmodell | 24 kontroller bestått |
| Ny Ada feilgrense | 37 kontroller bestått |
| Faktisk motor-/sikkerhetskode mot simulert I2C | 67 kontroller bestått |
| Sum Ada | **1857 kontroller** |
| Python | **35 tester**, hvorav seks nye |
| Negativ kontroll | Fjerning av stoppflagget i en isolert midlertidig kodekopi blir oppdaget av testene |
| ARM hovedprogram | Bygg/link/HEX bestått; flash 220428 B, SRAM-region 29144 B |
| ARM diagnostikk V2 | Bygg/link bestått; flash 220580 B, SRAM-region 29024 B |
| ARM GPIO V3 | Bygg/link bestått; vist flash 147 KB, SRAM-region 27272 B |
| Firmwareadvarsler | 377 advarsler i første rene bygg; ordrett liste bevart |
| Rapport | Lokal pdfLaTeX/BibTeX: 54 sider totalt, 0 feil, 0 ordinære advarsler, 2 underfull og 0 overfull |
| Presentasjon | Lokal Beamer/pdfLaTeX: 10 lysbilder, 0 feil, 0 ordinære advarsler |

Maskinlesbart grunnlag, loggutdrag, kildehasher og firmwarehasher finnes i
`evidence/2026-11-02-pi/verification.json`. 104 nye Ada-kontroller er
programtester, ikke 104 fysiske forsøk. Ressurstall inkluderer lenkerens
regionregnskap; de er ikke målte stackmaksima eller WCET-bevis.

Byggeverktøy: Alire 2.1.1, pakkene `gnat_arm_elf=15.1.2`, `gprbuild=25.0.1`
og `gnatprove=15.1.0`, samt Debian GNAT 14.2 for native tester.
Alire-pakkenes versjoner avviker fra verktøyenes egne versjonstekster;
`doctor.txt` bevarer dette. Ingen nye GNATprove-bevis er kjørt.
LaTeX-verktøy er installert. PyOCD er foreløpig ikke installert.

## Rapport, presentasjon og kilder

Eksisterende `main.tex` er videreført med avsnitt 7.7, datert sammendrag,
KI-bruksbeskrivelse og nytt kodevedlegg. Historisk tekst er bevart. Den lange
rapporten er et utviklingsdokument; hoveddelen må ved sluttredigering
tilpasses oppgavens anbefalte 15–20 sider. Vesentlig Ada-kode kan stå i vedlegg.

`presentation.tex` er et redigerbart utkast på ti lysbilder. Det beskriver
arkitektur, feilrespons, tidsanalyse, matematikk, dokumenterte resultater og
gjenstående fysiske steg. Det er ikke en påstand om ferdig eksamensdemo.

Offisielle kilder er kontrollert: Ada RM 11.4, AdaCore runtime-dokumentasjon,
NXP PCA9685-datablad og micro:bit-stiftelsens USB-veiledninger. Referansene
er lagt i `bibliography.bib`. Pensumdekning kan ikke sluttkontrolleres uten
forelesningsmaterialet og gjeldende vurderingskriterier.

Eksisterende Overleaf-prosjekt viser «Begrenset … ikke tillatelse» i denne
nettleseren. **Overleaf er ikke oppdatert.** Kompilerte PDF-er og en komplett
Overleaf-kildepakke ligger lokalt under `build/deliverables/`. Hovedfil er
`main.tex`; presentasjonen bygges ved å velge `presentation.tex`.

## Reproduksjon og neste steg

Se `PI-OPPKOBLING.md` for USB, patch og byggkommandoer. Rapport/presentasjon:

```sh
cd docs
latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=../build/report main.tex
latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=../build/presentation presentation.tex
```

Det umiddelbare neste steget er brukerens bekreftelse av fysisk
motorstrømisolasjon, datakabel, nåværende firmware og pinneplan. Deretter
leses logg fra den faktiske micro:biten. Oppstart, flerpunktkalibrering,
svinger, lavfartskjøring og tidsmålinger følger i den rekkefølgen som er
beskrevet i `PENSUM-OG-DEMOPLAN.md`. Task-refaktorering med protected objects
og en riktig RTA-modell planlegges etter avklart pensum og målt grunnlag.
