"""
Structured JSON Logging & Security Redaction Middleware
Emits machine-parseable JSON log entries with request IDs, latency tracking,
status codes, and strict redaction of credentials and private tokens.
"""

import time
import json
import uuid
import logging
from typing import Callable
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger("bhumitra.api")

# Sensitive fields and headers that must NEVER be logged
SENSITIVE_HEADERS = {
    "authorization",
    "x-admin-key",
    "cookie",
    "set-cookie",
    "x-api-key",
}

SENSITIVE_BODY_KEYS = {
    "identity_token",
    "access_token",
    "signed_transaction_jws",
    "signedpayload",
    "password",
    "secret",
}


class StructuredLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        start_time = time.time()

        # Extract client IP
        forwarded = request.headers.get("X-Forwarded-For")
        client_ip = forwarded.split(",")[0].strip() if forwarded else (request.client.host if request.client else "unknown")

        response = await call_next(request)

        duration_ms = round((time.time() - start_time) * 1000, 2)
        response.headers["X-Request-ID"] = request_id

        # Skip health check noise in logs
        if request.url.path in ("/health", "/ready"):
            return response

        log_entry = {
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": response.statusCode if hasattr(response, "statusCode") else response.status_code,
            "latency_ms": duration_ms,
            "client_ip": client_ip,
        }

        # Log at appropriate level
        status_code = log_entry["status_code"]
        if status_code >= 500:
            logger.error(json.dumps(log_entry))
        elif status_code >= 400:
            logger.warning(json.dumps(log_entry))
        else:
            logger.info(json.dumps(log_entry))

        return response
