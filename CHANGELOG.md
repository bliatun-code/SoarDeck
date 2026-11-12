# Changelog

## 2026.11-v3 - 2026-11-13

- Review flight time, altitude, climb and sink in the flight log. Motor gliders also show motor time and battery readings.
- Use a switch and throttle to show when the motor is ready and mark motor runs in the altitude history.
- The battery check now explains what to verify when approval is blocked. New setups default to 3S / 2200 mAh and enable the low motor battery alert.
- SoarDeck loads only for models that use it and frees its memory when you switch to another model. The flight count stays saved; last-flight details are cleared at the switch.
- Configure widget opens with the everyday settings. Turn on **Advanced settings** and reopen Configure to change damping, timeouts and motor and log thresholds.
- Less background work while another screen is shown. The package now has two Lua files: `main.lua` loads `deck.lua`. Copy both for manual installation.
- The flight-log update prepared as 2026.11-v2 was not released separately; it is included here.

## 2026.11-v1 - 2026-11-04

- Sensor setup helps you select altitude, vario, speed and radio-link sensors.
- Choose Motor glider to include motor-battery sensors. Review and confirm before saving.
- Improved handling of saved sensor selections.

## 2026.10-v2 - 2026-10-30

- Battery checks use a default 0.30 A idle-current floor, adjustable to 1.50 A in 0.10 A steps under Motor battery. The capacity-dependent limit and existing qualification checks remain.
- Existing widgets receive the new setting without changing previous selections. Changing the floor requires a fresh battery check.
- Instruments require a widget area matching the actual LCD dimensions. Split areas show a setup notice; full-screen operation resumes automatically. Missing LCD metadata is retried at a bounded rate.

## 2026.10-v1

First stable SoarDeck release: four instrument styles, dynamic sailplane/motor-glider and picture/instrument layouts, altitude and vario history, native ETHOS vario-audio setup, and guarded motor-energy display. Includes battery acceptance across model reconnects and a bounded confirmation reading period.
