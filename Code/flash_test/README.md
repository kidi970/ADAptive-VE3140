# Sensor- og pipetest

Dette er den separate testen for ultralydsensor og piping. Programmet bruker
trigger P13, ekko P1 og den innebygde høyttaleren (P27). Det inneholder ingen
motor- eller hjulstyring.

Kjør fra roten av prosjektet:

```sh
python tools/mb.py build --use flash-test
```

Firmware legges i `build/main.hex`, `build/main.bin` og `build/main.elf`.
For å bygge og flashe testen på en lokalt tilkoblet micro:bit:

```sh
python tools/mb.py flash --use flash-test
```

I GitHub Actions ligger denne firmwaren i artefakten **Pipetest**.
Artefakten **ITRS** er hovedprogrammet i `Code/src`.

`Code/pipetest` inneholder foreløpig bare tomme Ada-filer. Den kjørbare
pipetesten ligger her i `Code/flash_test`; bruk prosjektvalget `flash-test`.

Et vellykket bygg bekrefter kompilering, ikke fysisk sensor- eller lydtest.
