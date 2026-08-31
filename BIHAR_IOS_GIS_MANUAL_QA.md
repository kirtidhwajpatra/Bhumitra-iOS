# Bihar iOS Cadastral GIS Manual QA Checklist

## Overview
This QA matrix guides manual verification of Bihar cadastral map rendering, hierarchy navigation, and plot selection within the Bhumitra iOS application.

---

### A. Bihar Happy Path
- [ ] 1. Open Location Picker Sheet (`CadastralVillagePickerSheet`).
- [ ] 2. Select **Bihar** via State Switcher.
- [ ] 3. Verify Step 1 shows "1. District" / "Select Bihar District". Select `Patna` (`BR_PAT`).
- [ ] 4. Verify Step 2 shows "2. Circle" / "Select Circle / Anchal". Select `Patna Sadar` (`BR_PAT_01`).
- [ ] 5. Verify Step 3 shows "3. Halka". Select `Halka 01` (`BR_PAT_01_01`).
- [ ] 6. Verify Step 4 shows "4. Mauza". Select `Begampur` (`BR_PAT_01_108`).
- [ ] 7. Sheet dismisses; camera smoothly animates to Begampur bounding coordinates.
- [ ] 8. Cadastral parcel polygons render on MapLibre view with high-contrast outlines.

### B. Bihar Map Rendering
- [ ] 1. Verify all plot boundaries render crisply.
- [ ] 2. Verify both single `Polygon` and `MultiPolygon` plots render without missing rings or visual artifacting.
- [ ] 3. Toggle between Satellite and Standard map layers; verify cadastral outlines remain sharp and visible.

### C. Plot Selection
- [ ] 1. Tap an arbitrary Bihar parcel (e.g. Plot `245`).
- [ ] 2. Verify tactile haptic feedback fires.
- [ ] 3. Verify the tapped parcel is highlighted with selection border.
- [ ] 4. Verify plot number card displays Khesra/Plot `245` with village and circle metadata.
- [ ] 5. Verify NO RoR / Jamabandi search is automatically triggered.

### D. Zoom & Pan Interaction
- [ ] 1. Pinch to zoom in from Level 14 to Level 20.
- [ ] 2. Verify plot labels and vector line widths scale smoothly without stutter.
- [ ] 3. Pan across village boundaries; verify frame rate remains solid (60/120 FPS).

### E. Orientation & Resizing
- [ ] 1. Rotate device between Portrait and Landscape; verify MapLibre canvas resizes cleanly.
- [ ] 2. Verify plot card overlay adapts to safe area insets.

### F. Background & Foreground Transitions
- [ ] 1. Send app to background while Bihar map is displayed.
- [ ] 2. Re-open app; verify map state and loaded parcels are fully restored without reloading flash.

### G. Network Loss & Offline Behavior
- [ ] 1. Enable Airplane Mode after loading Begampur map.
- [ ] 2. Pan and select previously loaded plots; verify in-memory cache responds immediately.
- [ ] 3. Attempt to load a new un-cached village; verify clear error message "Cadastral map unavailable" is displayed.

### H. Slow Network / Loading State
- [ ] 1. Simulate 3G network throttling.
- [ ] 2. Verify `ParcelLoadingIndicator` displays "Finding locations: Connecting to Bihar BhuNaksha directory".
- [ ] 3. Verify smooth transition once GeoJSON payload completes.

### I. Empty Response Handling
- [ ] 1. Load a village with 0 cadastral parcels.
- [ ] 2. Verify toast appears: "Cadastral parcel data is not available for this village."
- [ ] 3. Verify no crash or null pointer exceptions occur.

### J. Malformed Response Handling
- [ ] 1. Verify corrupted polygons or coordinates are dropped gracefully without crashing MapLibre.

### K. Large Map Guardrail
- [ ] 1. Attempt to load an oversized sheet ($>5,000$ parcels).
- [ ] 2. Verify HTTP 413 triggers friendly toast: "Village map too large to render safely".

### L. State Switch Verification (Odisha ↔ Bihar)
- [ ] 1. Load Bihar village map (e.g. `Begampur, Patna`).
- [ ] 2. Switch State to **Odisha** in Location Picker.
- [ ] 3. Select Odisha village (e.g. `G_Dimbo, Keonjhar`).
- [ ] 4. Verify Bihar polygons and bounds are completely cleared.
- [ ] 5. Verify Odisha polygons render at Keonjhar coordinates.
- [ ] 6. Switch back to **Bihar**; verify clean re-initialization with zero cross-state polygon contamination.
