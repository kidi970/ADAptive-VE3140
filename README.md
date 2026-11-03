# ADAptive – VE3140

Programvarearbeid 3. november 2026: **3716 native Ada-kontroller,
114 Python-tester, seks ARM-bygg og avgrenset SPARK-bevis består.**
Overleveringens standalone-kode er innlemmet med bevarte driverrettinger.
Logging har tids-/pollinggrense; benk-OLED tåler injiserte bussunntak.
Rene navigasjons-/stopplengdemodeller og historisk avspilling kjøres offline.

- [Utviklingslogg og avgrensninger fra denne økten](docs/ADAptive-utviklingslogg-2026-11-03.md)
- [Integrerbart LaTeX-kapittel](docs/software-only-2026-11-03.tex)
- [Rapport og Overleaf-pakke](docs/README.md), [hovedfil](docs/main.tex)
  og [presentasjon](docs/presentation.tex)
- [Forrige kodekontroll, bevart historikk](docs/ADAptive-kodekontroll-2026-11-02.md)

```sh
python3 tools/sync_report_sources.py
python3 tools/check_project.py --full --out build/software-only-2026-11-03/verified
python3 tools/package_delivery.py --tag programvare-2026-11-03 --verification build/software-only-2026-11-03/verified/verification.json
```

Disse kommandoene tester, bygger og pakker bare lokale filer. De åpner ikke
USB, serieport, debugprobe, GPIO eller I²C og flasher/resetter ikke kortet.
Native GNAT, den pinnede Alire-verktøykjeden og LaTeX kreves. Driverpatchen
må være anvendt én gang; se tidligere Pi-veiledning for nytt checkout.

**Fysisk status for denne øktens bygg: ikke testet.** Oppstart på kortet,
sensor-/bussfunksjon, lys, knappetrykk, sving, fart, bremsing, deadlines og
stackmaksimum er ikke bekreftet av mocks eller kompilering. Ingen fysisk
brukerhandling er etterspurt. Komponentprofilens benkpinner P0/P9/P16/P3
er forskjellige fra bilens lysplan P0/P12/P16. Offline-modellene gir ingen
ny motorautorisasjon i produksjonskoden.

Overleaf-nettprosjektet er **ikke oppdatert**: lokal nettlesertilgang er
deaktivert i Work. Den lokale rapporten og Overleaf-ZIP-en er oppdatert.
Historiske forsøksresultater og øvrig gruppearbeid er bevart i daterte
filer under `docs/` og i `docs/development-history.tex`. Pensum-PDF og
sensurveiledning er fortsatt ikke tilgjengelige for full faglig avstemming.
Den eldre kursmalens generelle bruksveiledning følger nedenfor.

---

<!-- No build badge here on purpose: a template is copied verbatim, so a badge
     pointing at the upstream repository would report the lecturer's build
     status inside every student's project. Check your own build under the
     Actions tab of your repository. -->

# Ada-Embedded-Project-MicroBitV2

Template for the USN BSc **Intelligent Real-Time Systems** course: Ada on the
BBC micro:bit v2.

## 1. Make your own copy

Click the green **Use this template** button at the top of this page and choose
**Create a new repository**. Give it a sensible name — it is your project for
the semester.

Everything below assumes you are working in *your* repository, not this one.

## 2. Pick how you want to work

| | Path | You install | Flashing | Debugging (F5) |
|---|---|---|---|---|
| 🟢 | **[In your browser](setup/codespace.md)** | **nothing** | from the browser | **[yes, from the browser](setup/debugging.md)** |
| 🔵 | **[On your own machine](setup/local.md)** | VS Code + Python, then one command | plugged in, or browser | **[yes](setup/debugging.md)** |

**Not sure?** Start with the browser. It needs nothing installed, works on a
school laptop or a Chromebook, and you can move to a local install later without
changing any code.

You need a **Chrome, Edge or Opera** browser to flash from the browser — Safari
and Firefox do not support WebUSB. Any browser works for editing.

## 3. Flash and read output

**<https://aiunderstand.github.io/Ada-Embedded-Project-MicroBitV2/>**

Connect the board, pick a firmware, flash it, and read `Put_Line` output at
115200 — all in one browser tab, nothing installed.

There are ready-built examples in the picker, so you can flash `music` or
`accelerometer` and see the board do something before writing any code.

**Working in a Codespace?** You do not have to download anything. Run the
**Flash from here (serve flasher)** task and open the forwarded port — the page
is then served from your Codespace with your own build already loaded.

## Debug with breakpoints

Set a breakpoint in `main.adb`, press **F5**, and step through your program on
the real board — on **both** paths, including in a browser Codespace. See
**[Debug with breakpoints](setup/debugging.md)** for the keys, the limits, and
how it works.

## What is in here

```
Code/src/main.adb           your program -- this is the file you edit
Code/itrs.gpr              the project file
Code/libs/Ada_Drivers_Library   drivers and 46 examples (a git submodule)
tools/mb.py                build / flash / prove driver
```

Common commands, from the repository root:

```shell
python3 tools/mb.py doctor              # is my setup working?
python3 tools/mb.py list                # what can I build?
python3 tools/mb.py build               # build your project
python3 tools/mb.py flash               # build and flash (needs a plugged-in board)
python3 tools/mb.py build --use ravenscar/music   # build any example
python3 tools/mb.py prove --use spark/bounded_queue
```

In VS Code, **Ctrl+Shift+B** does the common one, and *Tasks: Run Task* has the
rest — including **Choose project…** for building and flashing any of the 46 examples without
closing the folder.

## Examples

`Code/libs/Ada_Drivers_Library/examples/MicroBit_v2/` has three families:

* **`ravenscar/`** — 27 examples using the full runtime: display, accelerometer,
  radio, motors, tasking.
* **`zfp/`** — 15 smaller examples on the light runtime.
* **`spark/`** — 4 examples that are *formally proved* with GNATprove, not just
  tested. Start with `spark/bounded_queue`.

## Automation in this template

* GitHub Actions builds your code on every push and publishes `main.hex` as a
  downloadable artifact.
* The same workflow checks the build on Linux, macOS and Windows, builds all 47
  projects, and proves the SPARK examples.
* Dependabot keeps the drivers submodule up to date, monthly.

## This template uses

Three extensions: the Ada language server (**AdaCore.ada**), the micro:bit
flasher (**AIUnderstand.microbit-flasher**), which a Codespace installs into
your browser by itself, and **Cortex-Debug** for F5 — installed in a Codespace,
offered locally the first time you press F5. [Alire](https://alire.ada.dev/)
supplies the toolchain.

## Working on the template (maintainers)

Building, testing and publishing the flasher and companion extensions is
documented in **[setup/extensions.md](setup/extensions.md)**. Repository-wide
working notes — the toolchain pins, the traps, the CI layout — are in
`CLAUDE.md`.


## ADAptive status 23.10.2026: 60 cm sensorreferanse

Tre stasjonære GPIO-serier ga 480/480 gyldige venstremålinger, men middel 57,108 cm mot oppgitt 60 cm. P0 er fortsatt åpent for elektrisk kontroll, kalibrering og I2C-oppstartsfeil. Ingen nye bevegelsestester. Se [utviklingslogg](docs/ADAptive-reference60-2026-10-23.md), [rådata og tester](docs/evidence/2026-10-23-reference60/) og [sensorprotokoll](docs/SENSORPROTOKOLL.md).
