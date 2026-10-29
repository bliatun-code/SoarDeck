# Konfigurere SoarDeck

**SoarDeck 2026.10-v2** · [Bildeguide: alle 16 oppsett](Bildeguide-norsk.md)

[English](Configuration.md) · [Oversikt og installasjon](../README.md)

## Velg modell og visning

Åpne widgetmenyen og **Configure widget**. Under **Model / appearance** velger du:

- **Model type:** Sailplane fjerner motorbatterifeltet. Motor glider legger til en kompakt motorreserve.
- **Display style:** Deck har store digitale tall, Classic fremhever runde instrumenter,
  Thermal fremhever historikk, og Daylight har lys bakgrunn.
- **Model image:** Selected model bruker ETHOS-modellens bilde; Image file velger en egen fil;
  Hidden fordeler hele bildefeltet til instrumentene.
- **Units:** Metric viser meter, m/s og km/t; Imperial viser fot, ft/min og mph.

Bruk vanlig **8-bit RGB/RGBA PNG**, gjerne med gjennomsiktig bakgrunn. Bildet kan ha høyst
**160 000 piksler**, bredde 800 og høyde 480. Et bilde på 320 × 180 passer godt. 800 × 480
overskrider pikselgrensen. Sideforholdet beholdes. Velg Hidden for ren instrumentering.
For **Image file** kopierer du bildet til `/bitmaps/models/` på radioen og velger det i feltet
**Image file**. Modellbilder følger ikke med i widgetens ZIP-fil.

## Bruk et fullskjermsfelt

Widgetfeltet må ha samme bredde og høyde som radioens faktiske LCD. Dette er ikke en fast grense på
800 × 480; også en mindre LCD med et like stort widgetfelt er fullskjerm. Et delt felt viser
**Full screen required** og fjerner det gamle instrumentbildet. Velg fullskjerm igjen for å få
instrumentene automatisk tilbake. Hvis LCD-målene mangler eller er ugyldige, vises
**Screen size unavailable** mens appen prøver på nytt med avgrenset hyppighet. Telemetriberegning,
batterigodkjenning, tidtakere, historikk og varsler fortsetter i disse informasjonstilstandene.

## Velg høyde og VSpeed

Oppdag mottaker/sensorer i ETHOS-telemetri først. Velg etter faktisk måling, ikke bare et kjent navn.
En mottaker med integrert barovario eller et kompatibelt løst variometer kan gi høyde og vertikalfart.
Har du flere barometre, velg et sammenhørende høyde-/VSpeed-par.

1. Sett **Altitude source** til en levende høydemåling i meter eller fot.
2. Sett **VSpeed source** til målt vertikalfart, normalt i m/s.
3. Velg **Altitude reference → Relative to zero**, og bruk **Zero altitude → Zero...** på bakken.
   Gjenta ved starten av hver flyøkt.
4. La **Derive vario from alt** være av når en ordentlig VSpeed-kilde finnes.

Relativ modus viser `ALT REL` fra nullpunktet. Dette er ikke terrengfølgende AGL.
**Sensor altitude** viser kildens høyde uendret; referansen avhenger av sensoren og ETHOS-oppsettet.
Appen etablerer ikke QNH eller høyde over havet. Nullstilling sperres under aktiv flyging, med motoren
i gang, eller når en valgt fly-/motorbryter har ukjent tilstand.

I **Relative to zero** starter **Zero altitude** også maksimal høyde, høydegevinst, snitt og historikk
på nytt fra nullpunktet. Fly-/motortid og batteriforbruk beholdes. I **Sensor altitude** lagres bare et
nullpunkt for senere relativ visning; høyden, statistikken og historikken i sensorvisningen beholdes.

Bytte av **Altitude source** sletter det lagrede relative nullpunktet og starter høydestatistikk,
snitt og historikk på nytt. Nullstill den nye kilden på bakken før du bruker relativ høyde.
Bytte av **Altitude reference** starter også denne statistikken, snittet og historikken på nytt,
men beholder det relative nullpunktet. Begge endringer beholder fly-/motortid og batteriforbruk.

**Derive vario from alt** er en visuell reserve når bare høyde finnes. Den beregner endring mellom
gyldige høydemålinger og merker verdien som beregnet. Oppløsning og oppdateringstakt påvirker resultatet.
Den oppretter ingen beregnet VSpeed-kilde for native lyd. Vanlig barometrisk vertikalfart er verken
totalenergikompensert vario eller netto løft.

## Respons og historikk

Begynn med **Vario scale ±5 m/s**, **Display damping Normal (1.5 s)** og **Average period 20 seconds**.
Velg ±2,5 eller ±10 m/s for smalere/bredere skala. Dempingen gjelder appvisningen, ikke sensoren eller
ETHOS-lyden. Gjennomsnittet kan være 5, 10, 20 eller 30 sekunder.

**History plot** velger høyde eller vario. **History window** velger 30/60 sekunder eller 2/5 minutter.
Motorkjøring markeres separat. Kurven viser utvikling, ikke termikkens posisjon. Manglende data bryter
historikk og snitt, slik at kurven ikke forbinder målinger over et telemetriavbrudd.

**Data timeout** er normalt 3 sekunder og tilpasses sensorens faktiske oppdateringstakt. Ugyldige/gamle
kilder gir streker eller utilgjengeligstatus; instrumentene flytter seg ikke. Selv med Imperial visning
angis **Vario scale** i m/s og **Height limit** i meter, slik feltene er merket.

Tidsgrensen bruker telemetrisensorens alder. En Lua-kilde eller beregnet kilde må selv melde manglende
måledata; SoarDeck kan ikke alderskontrollere et siste tall som kilden bare holder uendret.

## Sett opp variopip i ETHOS

SoarDeck bruker ETHOS sin innebygde variolyd. Appen lager ikke kontinuerlig variolyd selv.

1. Gå til **Model → Special functions** i ETHOS og legg til **Play vario**.
2. Velg **samme native VSpeed-kilde** som i SoarDeck.
3. Sett **State → Enable**, og velg en **fysisk aktiveringsbryter** under **Active condition**,
   slik at du kan slå lyden på og av.
4. Still **Range** og **Center** i funksjonen. Velg stille senterområde om ønskelig.
5. Under **System → General → Vario** stiller du volum, tonehøyde ved null/maks og repetisjon.

Stiging gir pip med stigende tonehøyde; synk gir sammenhengende tone med fallende tonehøyde.
Lyden er uavhengig av hvilken widget som vises. En `ETHOS`-indikasjon i SoarDeck beskriver lydopplegget;
den måler ikke om lyden faktisk er på. Synthetic preview slår ikke av en separat aktivert native vario.
Se [ETHOS Play vario](https://ethos-doc.frsky-rc.com/model-setup/special-functions/) og
[varioinnstillinger](https://ethos-doc.frsky-rc.com/system-setup/general/).

## Legg til relevante ekstrafelt

Velg **RX voltage**, **TX voltage** og **Link / Rx VFR** under RX / link. Bruk mottakerens aktuelle
linkmåling; enheten skiller prosent fra dB. RX-spenning er mottakerens/BEC-ens forsyning og er ikke
motorbatteriets ladetilstand.

Slå bare på **Show pitot airspeed** med en reell pitotkilde. **Show GPS ground speed** bruker en separat
GPS-fartskilde. GPS-bakkefart er ikke IAS og kan ikke gi stallindikasjon. Verken pitot eller GPS trengs
for grunnvisningen med høyde og vario.

## Konfigurer motorbatteriet

Disse feltene gjelder **Motor glider**. Sett **Chemistry**, **Capacity** og **Cells** etter den faktiske
pakken. Velg fremdriftsbatteriets kilder; ikke bruk BEC-utgang eller mottakerspenning som erstatning.

| Remaining from | Nødvendig oppsett | Betydning |
| --- | --- | --- |
| Consumed mAh | Pakkespenning, strøm, forbrukt-mAh-kilde og riktig kapasitet | Kapasitet minus godkjent forbruksteller |
| Percent sensor | Gyldig kilde på 0–100 % | Sensorens prosent, uten spenningsreserve |
| Voltage estimate | Pakkespenning, kjemi og celletall | Omtrentlig spenningsbasert prosent, merket som anslag |

Velg **Lowest cell voltage** bare fra en virkelig cellemåling. Pakkevolt delt på celletall avslører ikke
den svakeste cellen. En strømsensor trenger en egnet forbrukt-mAh-kilde i ETHOS. Appen finner ikke på
forbruk fra motortid og integrerer ikke strøm når en forbruksteller mangler.

For Consumed mAh trenger hvert nytt batteri **10 sammenhengende sekunder** med høyst **0,20 V variasjon
for hele pakken**, og strøm høyst
`min(1,5 A; max(Idle current floor; 3 × kapasitet_mAh / 20000))`.
**Idle current floor** er normalt **0,3 A** og kan økes til **1,5 A** i trinn på **0,1 A**.
Feltet er tilgjengelig for Motor glider med Consumed mAh; andre målemetoder beholder sin egen oppførsel.
Med standardverdien tillates opptil 0,3 A for pakker på 450–1500 mAh, mens 3300 mAh tillater 0,495 A.
Servolast over den effektive grensen kan fortsatt avbryte kontrollen selv om motoren er stoppet.
Endring av minstegrensen starter en ny batterikontroll. Eksisterende widgeter får standardverdien
0,3 A og beholder alle andre innstillinger. Verdien lagres med widgeten.

Inntil kontrollen er godkjent, er prosent og gjenværende mAh ukjent. Største avvik mellom teller og
spenningsreferanse på høyst 10 prosentpoeng kan godkjennes automatisk. Over 10 til og med 20 krever
**Battery counter → Accept...**, etter kontroll av faktisk lading, celler, kjemi, kapasitet og teller.
Over 20 kan ikke godkjennes. For høy spenning krever retting av celler/kjemi. LiFe krever manuell
bekreftelse fordi den flate spenningskurven ikke pålitelig kan bekrefte lading.

Manuell godkjenning krever kjent motor OFF. Med valgt motorkilde må den aktuelle målingen være
gyldig og på eller under **Motor ON above**; ellers må gyldig strøm være under **Motor current gate**.
Appen kontrollerer dette på nytt når **Confirm** trykkes, slik at en åpen dialog ikke kan godkjenne
telleren etter at motoren er armert. Manuell godkjenning kontrollerer også den samme effektive
hvilestrømgrensen. **Motor current gate** er en separat innstilling for motorstatus og erstatter ikke
batterikontrollens strømgrense.

Etter godkjenning starter ikke normalt spenningsfall eller motorlast sammenligningen på nytt.
Uventet fall i forbrukstelleren gjør gjenværende kapasitet ukjent og krever ny kontroll og uttrykkelig
godkjenning. **Pack loss delay** er normalt 10 sekunder; langvarig bortfall starter en ny batteriøkt.
Kort bortfall gir manglende verdier og godkjenner ikke en tellernullstilling. Etter radioomstart må
batteriet kontrolleres igjen. Motorstopp og ny flyging beholder batteriforbruket.

Batteriet er grønt over 40 %, gult ved 40 %, oransje ved 35 % og rødt ved 30 % eller lavere.
**Low motor battery** slår på eget lydvarsel ved **Battery reserve**, normalt 30 %.
Ukjent verdi skal ikke gi et falskt nullkapasitetsvarsel.

## Flytid og motortid

Med **Flight timer from → Flight switch / manual** velger du **Flight active switch** eller bruker
**Start flight / End flight** i widgetmenyen. En valgt bryter overstyrer manuell start/stopp.
Motor OFF avslutter ikke en seilflyging.

**ETHOS timer** viser valgt radiotimer. Flybryteren/manuell flytilstand bestemmer fortsatt aktiv flyging
for oppsamling av motortid. **Motor active switch** og **Motor ON above** bestemmer motorstatus.
Uten valgt motorkilde sammenlignes gyldig strøm med **Motor current gate**, normalt 2 A.
En bryter viser en kommando, ikke bevis på at motoren faktisk roterer.

**New flight → Reset...** nullstiller appens fly-/motortid, maksimal høyde, høydegevinst, snitt og historikk
på bakken.
Batteriforbruk og valgt høydereferanse beholdes. Nullstill høyde separat.

## Varsler og forhåndsvisning

Slå på **Height alert**, og sett **Height limit** i meter for valgt høydereferanse.
**Alert repeat** gjelder appens høyde-/batterivarsler, ikke variopipene i ETHOS.

**Synthetic preview** viser illustrasjonsverdier med appvarsler, ekte flytelling og batterigodkjenning
deaktivert. Slå den av for levende telemetri, og bruk variobryteren separat.
