# Uttar Pradesh Map Prototype — Device Test Checklist

Status: prototype only; hidden in Release because `up_map_enabled=false`. The shared Debug scheme explicitly sets `BHUMITRA_UP_MAP_PROTOTYPE=1`.

## Install and enter UP mode

1. Run the **MyBhoomi** scheme on an iPhone from Xcode.
2. Open **Settings → Uttar Pradesh map (Beta)**.
3. Choose District → Tehsil → Village. The lists are currently Hindi-first; each picker search also accepts the numeric code below.
4. Confirm the app flies to the village, switches to satellite, shows plot lines, and displays the `UP map · beta · tap a plot` pill.

## Five live test villages

| District | Tehsil | Village |
|---|---|---|
| `159` फर्रूखाबाद | `00830` कायमगंज | `145758` ज्योना |
| `133` मुजफफर नगर | `00711` जानसठ | `111455` रहडवा कदीम |
| `200` सोनभद्र | `01005` राबर्टसगंज | `213535` सेमरा |
| `173` प्रतापगढ | `00880` लालगंज | `158046` डीह मेहदी |
| `186` सन्तकबीर नगर | `00942` खलीलाबाद | `182395` पचपेड़ा |

For each village:
- Plot lines appear above the satellite imagery by zoom 13 and remain aligned while panning/zooming.
- The map stays smooth; tiles normally arrive in under 1 second.
- Tap several enclosed plots. A plot card should normally appear in under 1–2 seconds. A legitimate gap may show “No plot at this spot.”
- The card shows only plot number, khata number and area. It must never show an owner name.
- Searching a plot number from the card should move to its bounding rectangle.
- “View official record on UP Bhulekh” opens the official website.

## Mode and Odisha regression

1. Open a known Odisha village (for example Tampo) before entering UP.
2. Enter a UP village, then press **Exit**.
3. Confirm the previous camera/base-map choice returns and the Odisha village reloads.
4. Re-test Odisha direct search for `Tampo`, `Patia 547`, an Odisha map tap and GPS.
5. While a UP village is loading, close the picker. Confirm it does not enter UP later.
6. While a plot-number search is loading, dismiss the card. Confirm it does not reopen.

## Kill switches

- **Client discovery flag:** production app-config remains `up_map_enabled=false`, so Release builds show no UP entry. Debug is opted in only by the shared Xcode scheme environment variable.
- **Backend stop switch:** set `UP_GIS_PROVIDER_ENABLED=false` in `/etc/bhumitra/bhumitra.env` and restart. All UP data/tile routes must return `503 UP_GIS_DISABLED`; Odisha health/search must remain 200.
- Re-enable the backend flag after the check. Do not turn `up_map_enabled` on for users until this checklist passes.

## Known prototype limits

- Plot boundaries are raster images; the yellow selected rectangle is a bounding box, not the exact plot polygon.
- Hindi-first village lists; English transliteration/search is deferred.
- Official owner details are intentionally not returned by the Bhumitra API. Use the official UP Bhulekh link.
