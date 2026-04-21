# Raspberry Pi 5 — 3.5" TFT (ST7796) Wiring Schematic

Target board: Raspberry Pi 5 (16 GB), 40-pin GPIO header
Display: Generic 3.5" TFT, controller `ST7796`, SPI interface
Header on display (9 pins, top silkscreen): `GND VCC SCL SDA RST DC CS BL SDA-O`

## Display mode jumpers (back of TFT)

The `IMx` jumper table on the board selects the parallel/SPI mode.
Set the solder jumpers for **4-wire SPI**:

```
         P8   P16   SPI   SPI3
  IM0     1    0     1     1
  IM1     1    1     1     0
  IM2     0    0     1     1     <- use this column
```

→ `IM0 = 1`, `IM1 = 1`, `IM2 = 1` (4-wire SPI, standard).
Use `SPI3` column only if you must free up the `DC` line (3-wire mode).

## Pin map

```
  RPi 5 (40-pin, BCM numbering)              3.5" TFT (ST7796, SPI)
  ┌────────────────────┐                   ┌───────────────────┐
  │  1  3V3  ──────────┼─── red ──────────▶│ VCC   (3.3 V in)  │
  │  6  GND  ──────────┼─── black ────────▶│ GND               │
  │ 19  GPIO10 MOSI ───┼─── blue ─────────▶│ SDA   (MOSI)      │
  │ 21  GPIO9  MISO ───┼─── green ────────▶│ SDA-O (MISO, opt) │
  │ 23  GPIO11 SCLK ───┼─── yellow ───────▶│ SCL   (SCK)       │
  │ 24  GPIO8  CE0  ───┼─── orange ───────▶│ CS                │
  │ 18  GPIO24      ───┼─── purple ───────▶│ DC    (A0/RS)     │
  │ 22  GPIO25      ───┼─── white ────────▶│ RST               │
  │ 12  GPIO18 PWM0 ───┼─── brown ────────▶│ BL    (backlight) │
  └────────────────────┘                   └───────────────────┘
```

### Physical pin reference (40-pin header, top view, USB ports facing you)

```
              3V3  (1) (2)  5V
         GPIO2/SDA (3) (4)  5V
         GPIO3/SCL (5) (6)  GND        ◄── TFT GND
            GPIO4  (7) (8)  GPIO14/TXD
              GND  (9)(10)  GPIO15/RXD
           GPIO17 (11)(12)  GPIO18     ◄── TFT BL
           GPIO27 (13)(14)  GND
           GPIO22 (15)(16)  GPIO23
              3V3 (17)(18)  GPIO24     ◄── TFT DC
       GPIO10/MOSI(19)(20)  GND
       GPIO9/MISO (21)(22)  GPIO25     ◄── TFT RST
       GPIO11/SCLK(23)(24)  GPIO8/CE0  ◄── TFT CS
              GND (25)(26)  GPIO7/CE1
            GPIO0 (27)(28)  GPIO1
            GPIO5 (29)(30)  GND
            GPIO6 (31)(32)  GPIO12
           GPIO13 (33)(34)  GND
           GPIO19 (35)(36)  GPIO16
           GPIO26 (37)(38)  GPIO20
              GND (39)(40)  GPIO21
```

## Wiring table (quick reference)

| TFT pin | Signal        | Wire colour (above) | RPi5 physical | RPi5 BCM     |
|---------|---------------|---------------------|---------------|--------------|
| VCC     | +3.3 V        | red                 | 1             | 3V3          |
| GND     | Ground        | black               | 6             | GND          |
| SCL     | SPI clock     | yellow              | 23            | GPIO11 SCLK  |
| SDA     | SPI MOSI      | blue                | 19            | GPIO10 MOSI  |
| SDA-O   | SPI MISO*     | green               | 21            | GPIO9  MISO  |
| CS      | Chip select   | orange              | 24            | GPIO8  CE0   |
| DC      | Data/Command  | purple              | 18            | GPIO24       |
| RST     | Reset         | white               | 22            | GPIO25       |
| BL      | Backlight en  | brown               | 12            | GPIO18 PWM0  |

\* `SDA-O` is only needed if you want to read back from the controller
(touch read-back, register read). For display-only use you can leave it
floating.

## Power notes

- **Do NOT connect VCC to 5 V.** The ST7796 logic is 3.3 V; the board
  has no level shifter on the signal pins (only a regulator feeding the
  panel). Use physical pin 1 or 17 (3V3).
- Backlight `BL` draws ~80–150 mA. If you don't want PWM dimming, tie
  `BL` directly to 3V3 (pin 17) instead of GPIO18.
- Add a 0.1 µF decoupling cap between VCC and GND close to the TFT
  header if you see flicker on long jumper leads.

## Software (Raspberry Pi OS, Bookworm, Pi 5)

Pi 5 uses the RP1 southbridge, so legacy `fbtft` overlays from older
Pi's are **not** loaded the same way. For an ST7796 SPI panel:

1. Enable SPI in `raspi-config` → Interface Options → SPI → Enable.
2. Append to `/boot/firmware/config.txt`:

   ```ini
   dtparam=spi=on
   dtoverlay=mipi-dbi-spi,spi0-0,speed=32000000
   dtparam=compatible=ilitek,ili9486\0panel-mipi-dbi-spi
   dtparam=write-only
   dtparam=reset-gpio=25
   dtparam=dc-gpio=24
   dtparam=backlight-gpio=18
   dtparam=width=480,height=320,width-mm=73,height-mm=49
   ```

   (Use the `panel-mipi-dbi-spi` driver; ST7796 is register-compatible
   with ILI9486 init. Adjust `speed` down to 16 MHz if you see tearing.)

3. Reboot. The panel appears as `/dev/fb1` (or as a DRM device under
   `/dev/dri/card1` on current kernels). Use `con2fbmap 1 1` to push
   the console to it, or configure the compositor (Wayland/X11) to
   target the DRM node.

## Touch (optional)

The bottom FFC on the TFT is the touch-panel connector (XPT2046
resistive on most 3.5" ST7796 modules). If you're only wiring the
9-pin SPI header above, touch is **not** connected — you'd need the
separate touch breakout or the combined header variant.
