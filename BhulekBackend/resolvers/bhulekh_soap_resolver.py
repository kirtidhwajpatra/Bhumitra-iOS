"""
Bhulekh Official SOAP Helper
Resolves parent Khata for a given plot number via BhulekhService.asmx Unicode web methods.
"""
import asyncio
import logging
import httpx
from bs4 import BeautifulSoup

logger = logging.getLogger("bhumitra.soap")

# In-memory LRU cache for (district_id, tahasil_id, village_id, plot) -> parent_khata
_PLOT_KHATA_CACHE: dict[tuple[str, str, str, str], str] = {}

async def resolve_khata_for_plot_soap(d_code: str, t_code: str, v_code: str, target_plot: str) -> str:
    """
    Queries official KhatiyanUnicode and PlotsUnicode to find which Khata owns target_plot.
    Returns the exact official Khata number as string, or None if not found.
    """
    clean_target = target_plot.strip()
    cache_key = (str(d_code), str(t_code), str(v_code), clean_target)
    if cache_key in _PLOT_KHATA_CACHE:
        logger.info(f"[SOAP Cache] HIT: Plot '{clean_target}' -> Khata '{_PLOT_KHATA_CACHE[cache_key]}'")
        return _PLOT_KHATA_CACHE[cache_key]

    url = "https://bhulekh.ori.nic.in/BhulekhService.asmx"
    headers_k = {
        "Content-Type": "text/xml; charset=utf-8",
        "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/KhatiyanUnicode"
    }
    body_k = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <KhatiyanUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>{d_code}</dCode>
      <tCode>{t_code}</tCode>
      <vCode>{v_code}</vCode>
    </KhatiyanUnicode>
  </soap:Body>
</soap:Envelope>"""

    try:
        limits = httpx.Limits(max_connections=100, max_keepalive_connections=50)
        async with httpx.AsyncClient(timeout=15.0, verify=False, limits=limits) as client:
            r_k = await client.post(url, data=body_k, headers=headers_k)
            if r_k.status_code != 200:
                logger.warning(f"[SOAP] KhatiyanUnicode returned HTTP {r_k.status_code}")
                return None
                
            soup_k = BeautifulSoup(r_k.text, "xml")
            khatas = [t.text.strip() for t in soup_k.find_all("okhata_no")]
            if not khatas:
                return None

            headers_p = {
                "Content-Type": "text/xml; charset=utf-8",
                "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/PlotsUnicode"
            }
            sem = asyncio.Semaphore(50)
            found_khata = None

            async def check_khata(k: str):
                nonlocal found_khata
                if found_khata:
                    return None
                async with sem:
                    if found_khata:
                        return None
                    body_p = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <PlotsUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>{d_code}</dCode>
      <tCode>{t_code}</tCode>
      <vCode>{v_code}</vCode>
      <khata_no>{k}</khata_no>
    </PlotsUnicode>
  </soap:Body>
</soap:Envelope>"""
                    try:
                        r_p = await client.post(url, data=body_p, headers=headers_p)
                        if r_p.status_code == 200:
                            soup_p = BeautifulSoup(r_p.text, "xml")
                            plots = [p.text.strip() for p in soup_p.find_all("oplot_no")]
                            if clean_target in plots:
                                found_khata = k
                                return k
                    except Exception:
                        pass
                return None

            # Prioritize check if clean_target is in khatas
            if clean_target in khatas:
                res = await check_khata(clean_target)
                if res:
                    _PLOT_KHATA_CACHE[cache_key] = res
                    return res

            tasks = [asyncio.create_task(check_khata(k)) for k in khatas]
            for task in asyncio.as_completed(tasks):
                res = await task
                if res:
                    # Cancel pending tasks immediately for instant response
                    for t in tasks:
                        if not t.done():
                            t.cancel()
                    logger.info(f"[SOAP] Fast Resolved Plot '{clean_target}' -> Khata '{res}' in village {v_code}")
                    _PLOT_KHATA_CACHE[cache_key] = res
                    return res
    except Exception as e:
        logger.warning(f"[SOAP] Khata resolution failed: {e}")
        
    return None
