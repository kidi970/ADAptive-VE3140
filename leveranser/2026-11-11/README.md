# ADAptive – samlet leveranse 11. november 2026

Her ligger siste bilkode fra Raspberry Pi, med endringer til og med 4. november 2026 kl. 02:28, nybygd HEX og tilhørende koblingsplan.

- [ADAptive-siste.hex](ADAptive-siste.hex): firmware for micro:bit V2.
- [ADAptive-kildekode.zip](ADAptive-kildekode.zip): komplett byggeprosjekt med kildekode, lokale driverrettinger, prosjektfil, Alire-oppsett og byggeverktøy. Driverbibliotekets eksempler og genererte byggfiler er utelatt.
- [src/](src/): de samme 34 Ada-kildefilene, tilgjengelige direkte i GitHub.
- [Koblingsplan PDF](ADAptive-komplett-koblingsplan.pdf) og [pinneplan](PINNEPLAN.md).
- [Filkontroll](firmware-kontroll.json), [opprinnelse](opprinnelse.json) og [kontrollsummer](SHA256SUMS).

## Bygg kildekodepakken

Pakk ut `ADAptive-kildekode.zip` i en egen mappe. Kjør derfra:

```sh
python3 tools/mb.py build
```

Kommandoen lager `build/main.hex`, `build/main.elf` og `build/main.bin`. Den bruker Alire og den installerte verktøykjeden. Verktøyversjoner: gnat_arm_elf 15.1.2 og gprbuild 25.0.1. På en maskin uten verktøykjeden: kjør først `python3 tools/mb.py setup`.

Denne leveransens aktive program er `src/main.adb` og `Code/src/main.adb` inne i ZIP-en. Repoets eldre `Code/` på rotnivå er bevart separat; det inngår ikke i denne HEX-filen. Eksisterende GitHub Actions som bygger rotnivåets `Code/`, validerer derfor det eldre prosjektet.

## Kontroller

HEX er produsert ved ny kompilering. Alle 231196 programbyte er kontrollert mot ELF. Lastbart programinnhold er identisk med siste `room-range`-bygg på Pi-en. Den vedlagte ZIP-en er også pakket ut og bygd separat, og de lastbare programbytene er sammenlignet med HEX-filen. Ingen ny fysisk kjøretest eller flashing er utført.

Motorplasseringen i koblingsplanens side 1 og 6 er rettet til siste kode: M1 bak høyre, M2 foran høyre, M3 bak venstre, M4 foran venstre. Øvrig pinneplan er beholdt.

Firmware krever at P8 er konfigurert som GPIO i UICR; HEX-filen endrer ikke denne innstillingen. Ved aktiv NFC stopper programmet oppstarten. Se [pinneplanen](PINNEPLAN.md).

Kontroller nedlastede leveransefiler fra denne mappen med `sha256sum -c SHA256SUMS`.
