# ADAptive – OLED I2C Fix

## Background

The micro:bit V2 external I2C interface requires explicit GPIO
configuration for reliable communication with the SSD1306 OLED.

The fix configures SCL (P19) and SDA (P20) with:
- Input mode
- Internal pull-up resistors
- Connected input buffers
- Open-drain drive (S0D1)

OLED I2C address: 0x3C (7-bit).

## Apply the fix

Run these commands from the ADAptive repository root.

### 1. Initialize Git submodules

git submodule update --init --recursive

### 2. Verify the patch

git -C Code/libs/Ada_Drivers_Library apply --check ../../../patches/oled-i2c-fix.patch

### 3. Apply the patch

git -C Code/libs/Ada_Drivers_Library apply ../../../patches/oled-i2c-fix.patch

### 4. Build the firmware

python tools/mb.py build

## Verification

The OLED should display:
- ADAptive
- FRONT: XX CM

The HC-SR04 front sensor uses:
- TRIG: P13
- ECHO: P1 (through a voltage divider)

## Important

Apply the patch only once on a fresh checkout.

The Ada Drivers Library is a Git submodule.
The OLED fix is maintained as a project patch rather than
a separate commit in the upstream library.

# Current application patch, 23 October 2026

`ada-drivers-2026-10-23.patch` is cumulative against the repository's
Ada_Drivers_Library submodule HEAD. It includes external I2C GPIO setup,
ultrasonic timeout loops, and bounded I2C transmission used by the modular
application. Apply this patch to a clean submodule; do not first apply the
21 October patch. See `docs/ADAptive-utviklingslogg-2026-10-23.md` for the
tested scope, remaining hardware issues, and reproduction commands.
