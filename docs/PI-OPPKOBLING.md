# Raspberry Pi → ADAptive

**Oppfølging samme dag:** USB-kontakt er nå bekreftet på `/dev/ttyACM0`.
GPIO V3 ble verifisert byte for byte og sikkerhetskopiert før reset. En
320-raders serie uten sensorstrøm ga forventet NO_RISE. Deretter er egen
lysdiagnostikk lastet og tilbakeverifisert; 362 registerprøver bestod alle
seks mønstre. Micro:biten står nå med lysdiagnostikk, uten motor-/servo-I2C.
Se [lys og skanning](LYS-OG-SKANNING.md) for oppkobling av diodene.

Første kontroll 2. november 2026: utviklingsmaskinen er Raspberry Pi 5 Model B,
Debian 13 (aarch64). Ved kontrollen var ingen micro:bit registrert på USB.
Programmeringsverktøyene er installert og firmware er bygget på Pi-en.

## Koble bilen til Pi-en

1. Koble fysisk fra motorforsyningen **før** USB kobles til. Et program som
   allerede ligger på micro:biten kan starte straks USB gir strøm.
2. Behold micro:bit V2 i DFR0548-kortet. Bruk en **USB-datakabel** fra en
   USB-A-port på Pi-en til micro-USB-kontakten på micro:biten. En kabel som
   bare lader gir ingen programmering eller seriellport.
3. Behold Pi-ens egen strømforsyning. Ikke koble Pi-ens 5 V/GPIO til bilens
   VIN, motorer eller ECHO-ledninger. Bilen beholder sin eksisterende
   motor-/sensorforsyning; denne skal først aktiveres etter avklart oppsett.
4. Kjør fra prosjektmappen:

   ```sh
   python3 tools/pi_link.py status
   ```

   Det skal vises én micro:bit med VID `0x0d28`, PID `0x0204` og en port som
   `/dev/ttyACM0`. `status` åpner ingen seriellport og endrer ingen firmware.
   Pi-brukeren er allerede medlem av `dialout`.
5. Når motorstrømmen er fysisk isolert, les eksisterende program i 15 sekunder:

   ```sh
   python3 tools/pi_link.py listen --seconds 15 \
     --motor-power-disconnected --output build/pi-first-contact
   ```

   Verktøyet sender ingen kommandoer og utfører ingen reset eller flashing.
   Det forsøker å holde DTR/RTS lave; operativsystem/driver kan likevel endre
   kontrollinjer ved åpning. En ny mappe kreves for hver opptakssesjon.
   Stillhet er ikke bevis for stopp, riktig firmware eller feilfri elektronikk.

USB-forbindelsen støttes også på Raspberry Pi av micro:bit-stiftelsens
[tilkoblingsveiledning](https://support.microbit.org/support/solutions/articles/19000013984-how-do-i-connect-the-micro-bit-to-my-computer).
[Seriellinnstillingene](https://support.microbit.org/support/solutions/articles/19000022103-outputing-serial-data-from-the-micro-bit-to-a-computer)
er 115200 baud, 8 databiter, ingen paritet, én stoppbit. USB-identiteten er
[dokumentert av produsenten](https://support.microbit.org/support/solutions/articles/19000035697-what-are-the-usb-vid-pid-numbers-for-micro-bit).

## Fordeling av ansvar

```text
Raspberry Pi 5 ── USB data ── micro:bit V2 ── DFR0548 ── fire motorer
bygg / logging              Ada-styring       S2 ── frontservo
                            P13/P1 ── HC-SR04 front
                            P14/P2 ── HC-SR04 venstre
                            P15/P8 ── HC-SR04 høyre
                            P19/P20 ── ekstern I2C: DFR0548 og OLED
```

Dette er siste dokumenterte pinneplan, ikke en ny fysisk bekreftelse.
ECHO går gjennom en kontrollert spenningsdeler til micro:bitens 3,3 V-inngang.
Det var tidligere bekreftet at P2/P14 ikke delte LED-last; bekreft at dette
fortsatt gjelder. Micro:bit-pinnene P13/P1 er **ikke** Pi-ens GPIO-numre.

Autonomi skal kjøre lokalt på micro:biten. Pi-en brukes til å bygge, lese
logger og analysere forsøk. USB-frakobling er ikke implementert som nødstopp,
og Python-verktøyet gir ikke fjernstyring. Gjeldende Ada-kode leser sensorer,
beslutter og skriver motorer sekvensielt, med en avbruddsbasert stoppforespørsel.

## Reprodusere bygg

For et rent checkout på en ny maskin:

```sh
git submodule update --init --recursive
git -C Code/libs/Ada_Drivers_Library apply --check ../../../patches/ada-drivers-2026-10-23.patch
git -C Code/libs/Ada_Drivers_Library apply ../../../patches/ada-drivers-2026-10-23.patch
python3 tools/mb.py setup --no-install-tools --no-pyocd
python3 tools/mb.py doctor
python3 tools/test_navigation.py
python3 -m unittest discover -s tests -p 'test_*.py'
python3 tools/mb.py build
python3 tools/build_sensor_diagnostic.py
python3 tools/build_sensor_diagnostic.py --gpio-only
```

Driverpatchen er allerede lagt på i dette arbeidsområdet. Ikke legg den på en
gang til. `setup` kan melde at VS Code mangler selv om alle byggeverktøyene er
installert; `doctor` kontrollerer verktøykjeden. GNAT-versjonsnumrene i Alire
er pakkenumre og kan avvike fra versjonsteksten i kompilatoren.

Ingen av kommandoene over flasher bilen. `build/main.hex` er det **autonome**
hovedprogrammet. Den skal ikke brukes som erstatning for stasjonær diagnostikk.
Diagnostikk V3 bygger uten motor-/servo-/I2C-kommandoer; se
`SENSORPROTOKOLL.md` for den etablerte måleprosedyren og firmwareverifiseringen.
PyOCD 0.46.0 er i oppfølgingen installert i `build/pi-tools/` med PySerial og
pyelftools. Bruk `build/pi-tools/bin/python` for fysisk diagnostikk.
Vanlig bygg og passiv logging trenger ikke PyOCD. Lysdiagnostikk er flashet;
det autonome hovedprogrammet er ikke flashet.

## Neste fysiske steg

Bekreft faktisk pinneplan, spenningsdelere, felles jord, sensorforsyning og
hvilket program som ligger på micro:biten. Deretter samles oppstartsloggen
med motorstrøm isolert. Nytt program gir feiltype, I2C-status og register,
slik at den tidligere `PROGRAM_ERROR` kan lokaliseres. Ingen påstand om at
den fysiske feilen er rettet kan trekkes fra et vellykket bygg.

Når oppstart og stasjonære målinger er stabile, testes begge svingretninger
med løftede hjul, deretter oppmålt lavfartsbane med tilgjengelig strømbryter.
Knapp B er en programvarebasert stoppforespørsel, ikke en uavhengig elektrisk
nødstopp. Hjulretning, hastighet og stopplengde må fortsatt måles fysisk.
