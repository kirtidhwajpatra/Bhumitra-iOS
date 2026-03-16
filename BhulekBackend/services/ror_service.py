"""
RoR Service Layer
Core business logic for fetching and parsing Bhulekh RoR data.
"""
import logging
import hashlib
from cachetools import TTLCache
from typing import List, Dict, Optional
from models.ror_response import RoRResponse
from scrapers.bhulekh_scraper import BhulekhScraper

logger = logging.getLogger(__name__)

# Cache: max 500 entries, TTL = 1 hour (3600 seconds)
_cache: TTLCache = TTLCache(maxsize=500, ttl=3600)


def _cache_key(district: str, tahasil: str, village: str, plot: str, v_id: str | None = None) -> str:
    raw = f"{district}|{tahasil}|{village}|{plot}|{v_id or ''}"
    return hashlib.sha256(raw.encode()).hexdigest()


class RoRService:

    async def get_ror(
        self,
        district: str,
        tahasil: str,
        village: str,
        plot: str,
        b_id: str | None = None,
        v_id: str | None = None,
    ) -> RoRResponse:
        key = _cache_key(district, tahasil, village, plot, v_id)

        # 1. Serve from cache if available
        if key in _cache:
            logger.info(f"Cache HIT for key={key[:8]}...")
            return _cache[key]

        logger.info(f"Cache MISS — scraping Bhulekh for plot={plot}, village={village}")
        
        scraper = BhulekhScraper()
        
        try:
            # First Attempt: Use provided names
            result = await scraper.fetch_ror(
                district=district, tahasil=tahasil, village=village,
                plot=plot, b_id=b_id, v_id=v_id,
            )
            _cache[key] = result
            return result
            
        except ValueError as e:
            # Second Attempt: Simplified village name retry
            if "not found" in str(e).lower():
                import re
                simplified_village = re.split(r'[_\s]', village)[0]
                if simplified_village != village and len(simplified_village) > 3:
                    logger.info(f"Retrying with simplified village: {village} -> {simplified_village}")
                    try:
                        result = await scraper.fetch_ror(
                            district=district, tahasil=tahasil, village=simplified_village,
                            plot=plot, b_id=b_id, v_id=v_id,
                        )
                        _cache[key] = result
                        return result
                    except Exception:
                        pass
            raise e
            
        except Exception as e:
            logger.error(f"Scraper error: {e}", exc_info=True)
            raise ConnectionError(f"Temporary issue accessing portal: {str(e)}")

    async def get_ror_pdf(
        self,
        district: str,
        tahasil: str,
        village: str,
        plot: str,
        b_id: str | None = None,
        v_id: str | None = None,
    ) -> bytes:
        """
        Fetches the RoR and generates a PDF.
        """
        logger.info(f"PDF download request: district={district}, village={village}, plot={plot}")
        scraper = BhulekhScraper()
        
        try:
            return await scraper.download_ror_pdf(
                district=district, tahasil=tahasil, village=village,
                plot=plot, b_id=b_id, v_id=v_id,
            )
        except ValueError as e:
            # Second Attempt: Simplified village name retry
            if "not found" in str(e).lower():
                import re
                simplified_village = re.split(r'[_\s]', village)[0]
                if simplified_village != village and len(simplified_village) > 3:
                    logger.info(f"Retrying PDF download with simplified village: {village} -> {simplified_village}")
                    try:
                        return await scraper.download_ror_pdf(
                            district=district, tahasil=tahasil, village=simplified_village,
                            plot=plot, b_id=b_id, v_id=v_id,
                        )
                    except Exception:
                        pass
            raise e
        except Exception as e:
            logger.error(f"Scraper error downloading PDF: {e}", exc_info=True)
            raise ConnectionError(f"Temporary issue accessing portal: {str(e)}")
    async def list_districts(self) -> List[Dict[str, str]]:
        # Static list from mapping for speed
        from scrapers.bhulekh_mappings import DISTRICT_MAP
        # Remove duplicates and sort
        unique_districts = {}
        for name, d_id in DISTRICT_MAP.items():
            if d_id not in unique_districts or len(name) < len(unique_districts[d_id]):
                unique_districts[d_id] = name
        
        return sorted([{"id": d_id, "name": name} for d_id, name in unique_districts.items()], key=lambda x: x["name"])

    async def list_tahasils(self, district_id: str) -> List[Dict[str, str]]:
        cache_key = f"tahasils_{district_id}"
        if cache_key in _cache:
            return _cache[cache_key]
        
        scraper = BhulekhScraper()
        result = await scraper.list_tahasils(district_id)
        _cache[cache_key] = result
        return result

    async def list_villages(self, district_id: str, tahasil_id: str) -> List[Dict[str, str]]:
        cache_key = f"villages_{district_id}_{tahasil_id}"
        if cache_key in _cache:
            return _cache[cache_key]
        
        scraper = BhulekhScraper()
        result = await scraper.list_villages(district_id, tahasil_id)
        _cache[cache_key] = result
        return result
