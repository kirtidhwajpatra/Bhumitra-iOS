"""
Official RoR Document Cache
Stores and retrieves pre-rendered official Bhulekh RoR PDF documents keyed by canonical identity.
Prevents duplicate Playwright scraping sessions on PDF download.
"""
import os
import time
import hashlib
import logging
from typing import Optional, Dict, Any
from cachetools import TTLCache

logger = logging.getLogger("bhumitra.document_cache")

CACHE_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "document_cache")
os.makedirs(CACHE_DIR, exist_ok=True)


class OfficialDocumentCache:
    """Thread-safe memory + disk cache for official Bhulekh RoR PDFs."""

    def __init__(self, maxsize: int = 2000, ttl: int = 86400):
        self._mem_cache: TTLCache = TTLCache(maxsize=maxsize, ttl=ttl)
        self._meta_cache: TTLCache = TTLCache(maxsize=maxsize, ttl=ttl)

    @staticmethod
    def _file_path(canonical_id: str) -> str:
        safe_key = hashlib.sha256(canonical_id.strip().encode("utf-8")).hexdigest()
        return os.path.join(CACHE_DIR, f"{safe_key}.pdf")

    def store(self, canonical_id: str, pdf_bytes: bytes, metadata: Optional[Dict[str, Any]] = None) -> bool:
        """Stores official PDF bytes in memory and on disk keyed strictly by canonical identity."""
        if not canonical_id or not pdf_bytes:
            return False
        clean_id = canonical_id.strip()
        self._mem_cache[clean_id] = pdf_bytes
        self._meta_cache[clean_id] = {
            "canonical_id": clean_id,
            "created_at": time.time(),
            "size_bytes": len(pdf_bytes),
            **(metadata or {})
        }
        
        try:
            path = self._file_path(clean_id)
            with open(path, "wb") as f:
                f.write(pdf_bytes)
            logger.info(f"[DocumentCache] Stored official PDF for canonical_id '{clean_id}' ({len(pdf_bytes)} bytes)")
            return True
        except Exception as e:
            logger.warning(f"[DocumentCache] Failed to write PDF to disk for '{clean_id}': {e}")
            return True

    def get(self, canonical_id: str) -> Optional[bytes]:
        """Retrieves official PDF bytes for canonical_id from memory or persisted disk cache."""
        if not canonical_id:
            return None
        clean_id = canonical_id.strip()
        
        # 1. Check memory cache
        if clean_id in self._mem_cache:
            return self._mem_cache[clean_id]
        
        # 2. Check disk cache
        path = self._file_path(clean_id)
        if os.path.exists(path):
            try:
                with open(path, "rb") as f:
                    pdf_bytes = f.read()
                if pdf_bytes:
                    self._mem_cache[clean_id] = pdf_bytes
                    return pdf_bytes
            except Exception as e:
                logger.warning(f"[DocumentCache] Failed to read cached PDF from disk for '{clean_id}': {e}")
        
        return None

    def has(self, canonical_id: str) -> bool:
        """Checks if official document is available in cache."""
        if not canonical_id:
            return False
        clean_id = canonical_id.strip()
        if clean_id in self._mem_cache:
            return True
        return os.path.exists(self._file_path(clean_id))

    def clear(self):
        """Clears memory and disk cache."""
        self._mem_cache.clear()
        self._meta_cache.clear()
        try:
            for f in os.listdir(CACHE_DIR):
                if f.endswith(".pdf"):
                    os.remove(os.path.join(CACHE_DIR, f))
        except Exception as e:
            logger.warning(f"[DocumentCache] Failed to clear disk cache: {e}")


official_document_cache = OfficialDocumentCache()
