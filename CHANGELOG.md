# Changelog

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
