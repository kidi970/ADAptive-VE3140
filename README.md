# ADAptive – VE3140

**Siste samlede leveranse: [11. november 2026](leveranser/2026-11-11/).**

[Last ned HEX](leveranser/2026-11-11/ADAptive-siste.hex), [komplett kildekodepakke](leveranser/2026-11-11/ADAptive-kildekode.zip) eller [koblingsplan PDF](leveranser/2026-11-11/ADAptive-komplett-koblingsplan.pdf). [Se kildekoden direkte](leveranser/2026-11-11/src/).

Den daterte pakken inneholder kildekode fra Pi-en, firmware og koblingsplan kontrollert 11. november 2026. Senere endringer i hovedprogrammet ligger i `Code/src/`. Byggeinstruksjoner og kontrollresultater for pakken ligger i leveransemappen.

## Kode og versjoner

| Kilde | Hva den inneholder |
|---|---|
| [`Code/src/`](Code/src/) | Hovedprogrammet som bygges av `Code/itrs.gpr`. Ved revisjon `7fe1674` er dette en automatisk prøve på 60 trinn, med servoskanning og lydvarsling. |
| [`Code/flash_test/`](Code/flash_test/) | Separat sensor- og pipetest uten motorstyring. Bygges med `python3 tools/mb.py build --use flash-test`. |
| [`leveranser/2026-11-11/`](leveranser/2026-11-11/) | Datert pakke med modulær bilkode, firmware, koblingsplan og kontrollfiler. Den er et eget versjonsgrunnlag og har andre kildefiler enn rotnivåets `Code/src/`. |
| [Rapportens programvaregrunnlag, `a764c159`](https://github.com/kidi970/ADAptive-VE3140/tree/a764c159f5d79bbbb26c30b8940a8e6414b5db6a) | Fast revisjon for rapportens programvarekontroller. Benkresultater fra andre arbeidskopier må leses med versjonen og filmanifestet som er oppgitt i rapporten. |
| [`ADAptive Rapport.docx`](ADAptive%20Rapport.docx) | Historisk rapportutkast fra 7. oktober 2026. Den gjeldende rapporten bearbeides i Overleaf. |

## Medfølgende undervisningsmal

Dokumentasjonen nedenfor fulgte malen `Ada-Embedded-Project-MicroBitV2`. Henvisninger til foreleser, malvedlikehold, utvidelser og eierskap til driverforken gjelder originalprosjektet. `CLAUDE.md`, `SKILLS.md` og `.claude/` fulgte også malen og beskriver dens utviklingsverktøy. ADAptive er prosjektgruppens videreutvikling av dette grunnlaget.

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

* In ADAptive, GitHub Actions builds the main program and the separate sensor
  and beep test on Linux. It publishes the **ITRS** and **Pipetest** artifacts.
* The template's checks for multiple operating systems, all examples, SPARK
  proofs and extension regression tests are configured to run only in
  `aiunderstand/Ada-Embedded-Project-MicroBitV2`. They do not run in ADAptive.
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

