# PHASE 7.5 TRACE BLOCKER REPORT

CURRENT STEP:
Step 4 & Step 5: Plot Dropdown Population & Selection for Mega-Villages (>1,000 plots)

BLOCKING COMPONENT:
Playwright Browser Scraper / ASP.NET AJAX Dropdown Ingestion

FILE:
BhulekBackend/scrapers/bhulekh_scraper.py

FUNCTION:
BhulekhScraper._scrape()

WAITING TIME:
120.00 seconds (HTTP client request timeout triggered while Playwright waited on ASP.NET AJAX serialization of 5,537 `<option>` elements on `http://bhulekh.ori.nic.in/RoRView.aspx`).

LAST SUCCESSFUL STEP:
Village Resolution & Selection: Resolved `Raghunathpur_Jali` -> `359` (`ରଘୁନାଥପୁର ଜଳି`) in District `20` (Khordha), Tahasil `2` (Bhubaneswar).

LAST REQUEST:
`GET http://127.0.0.1:8000/api/v1/ror?district=Khordha&tahasil=Bhubaneswar&village=Raghunathpur_Jali&plot=333&b_id=2002&v_id=2002359`

LIKELY CAUSE:
1. **Mega-Village Dropdown Scale**: Raghunathpur Jali contains **5,537 plots**. When switching mode to `Plot` (`rbtnRORSearchtype_1`), the official ASP.NET server on `bhulekh.ori.nic.in` executes an AJAX postback that takes **45–90+ seconds** to transfer and render 5,537 `<option>` tags into `#ctl00_ContentPlaceHolder1_ddlBindData`.
2. **Hardcoded 10s Scraper Timeout**: `bhulekh_scraper.py:514` had a hardcoded `timeout=10000` (10 seconds) on `page.wait_for_function`. When this timed out before the 5,537 options finished populating, the scraper attempted to search an incomplete or empty dropdown, finding 0 matches for Plot 333 and raising `ValueError("Plot number '333' could not be verified...")`.
3. **SingleFlight / Request Hold**: While the scraper failed and tore down its page, the FastAPI async request handler was held, exceeding the HTTP client's 120s timeout.

PRODUCTION STATUS:
NO-GO
