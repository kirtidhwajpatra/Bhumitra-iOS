"""
Sliding Window Rate Limiter
Enforces tiered request rate limiting across anonymous IPs, authenticated users,
and high-load/scraping-triggering endpoints.
"""

import time
import threading
from typing import Dict, List, Tuple, Optional
from fastapi import Request, HTTPException, status


class SlidingWindowRateLimiter:
    def __init__(self):
        self._lock = threading.Lock()
        self._requests: Dict[str, List[float]] = {}

    def is_allowed(
        self,
        key: str,
        max_requests: int,
        window_seconds: int = 60,
    ) -> Tuple[bool, int, int]:
        """
        Determines whether a request with the given key is allowed under the sliding window.
        Returns: (is_allowed, remaining_requests, retry_after_seconds)
        """
        now = time.time()
        cutoff = now - window_seconds

        with self._lock:
            if key not in self._requests:
                self._requests[key] = []

            # Purge timestamps older than sliding window
            timestamps = [t for t in self._requests[key] if t > cutoff]
            self._requests[key] = timestamps

            if len(timestamps) >= max_requests:
                # Calculate when the oldest request in the window expires
                oldest_timestamp = timestamps[0]
                retry_after = max(1, int(oldest_timestamp + window_seconds - now))
                return False, 0, retry_after

            # Record current request timestamp
            self._requests[key].append(now)
            remaining = max(0, max_requests - len(self._requests[key]))
            return True, remaining, 0

    def cleanup(self):
        """Cleans up stale tracking entries to free memory."""
        now = time.time()
        cutoff = now - 3600  # Remove anything older than 1 hour
        with self._lock:
            stale_keys = [k for k, v in self._requests.items() if not v or v[-1] < cutoff]
            for k in stale_keys:
                del self._requests[k]


# Global rate limiter instance
limiter = SlidingWindowRateLimiter()


def get_client_ip(request: Request) -> str:
    """Extracts client IP considering standard reverse proxy headers."""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "127.0.0.1"


def enforce_rate_limit(
    request: Request,
    max_requests: int = 60,
    window_seconds: int = 60,
    user_id: Optional[str] = None,
    tag: str = "general",
):
    """
    FastAPI helper to enforce rate limiting on specific endpoints.
    Combines user ID (if available) or client IP.
    """
    identifier = user_id or get_client_ip(request)
    key = f"{tag}:{identifier}"

    allowed, remaining, retry_after = limiter.is_allowed(
        key=key,
        max_requests=max_requests,
        window_seconds=window_seconds,
    )

    if not allowed:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={
                "error": "rate_limit_exceeded",
                "message": "Too many requests. Please slow down and try again later.",
                "retry_after_seconds": retry_after,
            },
            headers={"Retry-After": str(retry_after)},
        )
