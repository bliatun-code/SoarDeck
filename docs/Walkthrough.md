# SoarDeck illustrated walkthrough

[Home](../README.md) · [Full setup guide](Configuration.md) · [Norsk](Bildeguide-norsk.md)

These are native **ETHOS 26.1.2 / X20RS, 800 × 480** simulator screenshots of SoarDeck 2026.10-v1.
Values are illustrative, not recorded flights or readings from connected hardware. Select your own discovered sources by measurement and unit;
names below are examples and can differ on your radio. The model picture does not choose sensors or configure the aircraft.

## 1. Basic sailplane: photo examples

Choose **Model type = Sailplane**, **Model image = Selected model**, **Units = Metric**.
Use the selected ETHOS model's picture. The example uses the simulator's glider artwork.
The motor-battery area disappears and the sailplane instruments use the available space.

| SoarDeck field | Example source | Hardware / origin |
| --- | --- | --- |
| Altitude source | Altitude — m | Integrated barovario, e.g. ARCHER Plus GR8 |
| VSpeed source | VSpeed — m/s | Same integrated barovario |
| RX voltage | RxBatt — V | Receiver supply telemetry; shown as 5.2 V here |
| Link / Rx VFR | Rx VFR — % | Receiver link telemetry; 99% here |
| TX voltage | TX battery — V | Radio source; 8.1 V here |
| Flight timer from / ETHOS timer | ETHOS timer / Flight timer — s | A configured radio timer; 07:17 here |
| Flight active switch | Flight | A deliberately selected switch for the app's flight state |

No motor-pack, pitot or GPS sensor is needed for this profile. **Show pitot airspeed** and **Show GPS ground speed** are off.
A compatible receiver without barovario can use an external **VARI ADV** instead: discover and select its matching Altitude/VSpeed pair.
An older VARI-H is an S.Port alternative; match the sensor and receiver port protocol.

## 2. Multiplex Heron: motor-glider photo examples

Choose **Model type = Motor glider**, **Model image = Selected model**, with the Heron image assigned to that ETHOS model.
The compact battery panel leaves room for altitude and vario. This is an example installation, not a claim about the Heron's fitted receiver or ESC.

Keep the baro/RX/link/timer sources above and add:

| SoarDeck field | Example source / setting | Hardware / meaning |
| --- | --- | --- |
| Remaining from | Consumed mAh | Capacity minus the accepted counter |
| Chemistry / Cells / Capacity | LiPo / 3 / 2200 mAh | Match the actual pack |
| Pack voltage | VFAS — V | Pack voltage from a suitably rated current sensor, e.g. FAS40 ADV |
| Current | Current — A | Same sensor, installed between pack and ESC |
| Consumed mAh | Consumption — mAh | ETHOS calculated Consumption sensor whose source is Current |
| Motor active switch | Motor | Motor command/arming state; verify OFF and ON |

The battery examples show **11.97 V**, **0.0 A**, **186 mAh consumed**, giving **2014 mAh / about 92%** after acceptance.
Receiver voltage is BEC/supply voltage and must not be selected as motor-pack voltage.
FAS40 ADV is only an example: check the actual drive's current and voltage against the sensor rating.
A telemetry ESC such as **Neuron II** can supply pack voltage, current and **ESC Consumption** directly, replacing the FAS/calculated-counter combination.
Do not assume a conventional ESC supplies these readings.

For a calculated counter, discover Current in **Model → Telemetry**, add a **Consumption** sensor using that current source and **mAh**,
then select it in SoarDeck. Its start/reset policy must match the battery actually fitted. A persistent counter cannot reconstruct consumption during missing telemetry.
After a new pack, allow the initial low-current check. Use **Accept battery...** when requested, check the actual pack and counter, then Confirm.
The confirmation allows up to 60 seconds of reading time and rechecks fresh inputs. Actual changes or loss can still require another check.

## 3. Instrument-only examples: add optional speed measurements

Choose **Model image = Hidden**. Instruments expand into the former picture area; there is no empty image placeholder.
The instrument-only examples retain the corresponding sailplane/Heron profile and configure both optional speed sources:

| Field | Example source | Additional sensor |
| --- | --- | --- |
| Show pitot airspeed / Airspeed source | On / Air speed — m/s | A compatible pitot sensor, e.g. ASS-70 with S.Port; example 18.5 m/s = 66.6 km/h |
| Show GPS ground speed / Ground-speed source | On / GPS speed — m/s | GPS ADV, matched S.Port/FBUS port; example 17.2 m/s = 61.9 km/h |

The selected style determines which optional readings fit. Classic's instrument-only views and Daylight's instrument-only Heron view show pitot airspeed here; these 16 captures do not show a GPS speed field. Deck and Thermal prioritize soaring readings and history in these configurations.
These sensors are optional and do not depend on hiding the picture; you can use either with a photo, or hide the photo and keep a minimal baro-only setup.
GPS speed measures movement over the ground. It is not airspeed. Neither these examples nor the app calculate a stall warning, TE or netto compensation.
Leave **Lowest cell voltage** blank unless a true cell measurement exists, for example from an FLVS ADV cell sensor with a suitable lowest-cell source.
Pack voltage divided by cell count is not the weakest cell.

## 4. Response, reference and sound

All examples use **Relative to zero**, **Vario scale ±5 m/s**, **Average period 20 s** and **History window 60 s**.
Zero altitude on the ground before the flight. The example sequence ends at +21.6 m and +1.8 m/s, with real app-generated averages/history from the illustrative sequence.
The Heron history marks a short initial motor phase; its final motor state is OFF. **Thermal** examples plot vario; the others use altitude history where that style displays it.
Try **Display damping = Normal (1.5 s)** first; it changes the visual response, not native audio.

For audio, create **Model → Special functions → Play vario**, select the same native **VSpeed** source and a physical activation switch.
Set its range/centre and the radio's **System → General → Vario** sound preferences. SoarDeck's ETHOS label is not proof the sound is enabled.

## 5. The 16 layouts

Each row shows the same style in four configurations. Click any image for the full-resolution simulator capture.

### Deck

| Sailplane with picture | Heron with picture |
| --- | --- |
| ![Deck sailplane](images/01-deck-sailplane-photo.png) | ![Deck Heron](images/02-deck-heron-photo.png) |

| Sailplane, instruments | Heron, instruments |
| --- | --- |
| ![Deck sailplane instruments](images/03-deck-sailplane-instruments.png) | ![Deck Heron instruments](images/04-deck-heron-instruments.png) |

### Classic

| Sailplane with picture | Heron with picture |
| --- | --- |
| ![Classic sailplane](images/05-classic-sailplane-photo.png) | ![Classic Heron](images/06-classic-heron-photo.png) |

| Sailplane, instruments | Heron, instruments |
| --- | --- |
| ![Classic sailplane instruments](images/07-classic-sailplane-instruments.png) | ![Classic Heron instruments](images/08-classic-heron-instruments.png) |

### Thermal

| Sailplane with picture | Heron with picture |
| --- | --- |
| ![Thermal sailplane](images/09-thermal-sailplane-photo.png) | ![Thermal Heron](images/10-thermal-heron-photo.png) |

| Sailplane, instruments | Heron, instruments |
| --- | --- |
| ![Thermal sailplane instruments](images/11-thermal-sailplane-instruments.png) | ![Thermal Heron instruments](images/12-thermal-heron-instruments.png) |

### Daylight

| Sailplane with picture | Heron with picture |
| --- | --- |
| ![Daylight sailplane](images/13-daylight-sailplane-photo.png) | ![Daylight Heron](images/14-daylight-heron-photo.png) |

| Sailplane, instruments | Heron, instruments |
| --- | --- |
| ![Daylight sailplane instruments](images/15-daylight-sailplane-instruments.png) | ![Daylight Heron instruments](images/16-daylight-heron-instruments.png) |

## Sensor references

- [ARCHER Plus GR8](https://www.frsky-rc.com/product/archer-plus-gr8/) and [VARI ADV](https://www.frsky-rc.com/product/vari-adv/): integrated or external barovario options.
- [FAS40 ADV](https://www.frsky-rc.com/product/fas40-adv/) and [Neuron II 60](https://www.frsky-rc.com/product/neuron-2-60/): alternative motor-energy measurement paths.
- [ASS-70](https://www.frsky-rc.com/product/ass-70/), [GPS ADV](https://www.frsky-rc.com/product/gps-adv/) and [FLVS ADV](https://www.frsky-rc.com/product/flvs-adv/): optional airspeed, ground speed and cell measurement.
- [ETHOS telemetry and calculated sensors](https://ethos-doc.frsky-rc.com/model-setup/telemetry/).

Use the exact product's manual for wiring, protocol and electrical limits. Sources with the same name can belong to different sensors.
