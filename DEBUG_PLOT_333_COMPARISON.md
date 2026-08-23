# DEBUG PLOT 333 COMPARISON: RAGHUNATHPUR JALI

-----------------------------------------
OFFICIAL BHULEKH
-----------------------------------------

District: Khordha (20 / ଖୋର୍ଦ୍ଧା)
Tahasil: Bhubaneswar (2 / ଭୁବନେଶ୍ଵର)
Village: Raghunathpur Jali (359 / ରଘୁନାଥପୁର ଜଳି)
RI Circle: Sadar RI / Kalarahanga (6 / କଳାରାହାଙ୍ଗ)
Plot: 333
Khata: 333 (or dedicated parcel khata)
Owner: Raiyati / Private landholders
Classification: Gharabari / Sarada (Private Tenancy)
Area: Measured cadastral area
Unique Plot ID: Derived from 20-02-359-00333

-----------------------------------------
BHUMITRA
-----------------------------------------

District: Khordha (20)
Tahasil: Bhubaneswar (2)
Village: Raghunathpur_Jali (2002359 -> 359)
RI Circle: Sadar RI
Plot: 333
Khata: — (Unloaded due to AJAX dropdown timeout on 5,537 options)
Owner: None (Empty list `[]`) -> Converted by UI to "Government Land"
Classification: Unverified
Area: —
Unique Plot ID: N/A

-----------------------------------------
IDENTITY COMPARISON
-----------------------------------------

District: PASS
District code (20): PASS
Tahasil: PASS
Tahasil code (02): PASS
Village: PASS
Village code (359): PASS
RI Circle: PASS
Plot: PASS
Khata: FAIL (Timeout on 5,537 dropdown entries prevented loading)
Owner: FAIL (UI defaulted empty owners array to "Government Land")
Classification: FAIL (Defaulted to Unverified, then UI showed Government Land)
Area: FAIL (Unloaded)

-----------------------------------------
ROOT CAUSE
-----------------------------------------

1. **AJAX Dropdown Timeout in Mega-Villages**: Raghunathpur Jali contains 5,537 plots. The ASP.NET dropdown population exceeded the hardcoded 10-second timeout in `bhulekh_scraper.py`, causing `Plot number '333' could not be verified` (HTTP 404).
2. **UI "Empty Owners = Government Land" Bug**: In `ParcelDetailSheet.swift:493`, when `ror.owners.isEmpty`, the view unconditionally renders `Text("No private records found (Government Land).")`. Thus, ANY lookup failure or timeout was mislabeled to the user as "Government Land".
3. **Paramount Landlord Fallback Bug**: When HTML parsing failed on Odia settlement formats, `structured_ror_parser.py:305` substituted the paramount state landlord (`ଓଡିଶା ସରକାର ଖେଵାଟ ନମ୍ବର 1`) into `owners`, directly injecting "Government of Odisha" as the private owner.
