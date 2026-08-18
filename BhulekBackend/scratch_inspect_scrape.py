import anyio
from scrapers.bhulekh_scraper import BhulekhScraper
from bs4 import BeautifulSoup

async def main():
    scraper = BhulekhScraper()
    # Let us run _execute_scrape directly and see what HTML is captured
    print("Testing _execute_scrape...")
    try:
        ror = await scraper.fetch_ror(
            district="KEONJHAR",
            tahasil="KEONJHAR SADAR",
            village="Dimbo",
            plot="12",
            b_id="0704",
            v_id="0704317"
        )
        print("Success:", ror)
    except Exception as e:
        print("Error:", e)

anyio.run(main)
