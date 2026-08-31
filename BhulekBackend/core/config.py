"""
Core Production Environment & Configuration Settings
Manages environment separation (development, staging, production),
database connection URLs, Apple StoreKit environments, and secret keys.
"""

import os
from typing import List
from pydantic import BaseModel, Field


class Settings(BaseModel):
    ENV: str = Field(default_factory=lambda: os.environ.get("ENV", "development"))
    DATABASE_URL: str = Field(default_factory=lambda: os.environ.get("DATABASE_URL", ""))
    JWT_SECRET_KEY: str = Field(default_factory=lambda: os.environ.get("JWT_SECRET_KEY", "bhumitra_dev_jwt_secret_change_in_prod"))
    ADMIN_API_KEY: str = Field(default_factory=lambda: os.environ.get("ADMIN_API_KEY", "bhumitra_admin_secret_key_2026"))
    APPLE_BUNDLE_ID: str = Field(default_factory=lambda: os.environ.get("APPLE_BUNDLE_ID", "com.kirtidhwaj.Bhumitra"))
    APPLE_ENVIRONMENT: str = Field(default_factory=lambda: os.environ.get("APPLE_ENVIRONMENT", "Sandbox" if os.environ.get("ENV", "development") != "production" else "Production"))
    
    LOG_LEVEL: str = Field(default_factory=lambda: os.environ.get("LOG_LEVEL", "INFO"))
    
    # Operational Concurrency & Scaling Controls
    BHULEKH_MAX_CONCURRENT: int = Field(default_factory=lambda: int(os.environ.get("BHULEKH_MAX_CONCURRENT", "3")))
    MAX_PENDING_BHULEKH_REQUESTS: int = Field(default_factory=lambda: int(os.environ.get("MAX_PENDING_BHULEKH_REQUESTS", "10")))
    
    # Bihar State Provider Scaling & Feature Flag Controls
    BIHAR_PROVIDER_ENABLED: bool = Field(default_factory=lambda: os.environ.get("BIHAR_PROVIDER_ENABLED", "false").lower() == "true")
    BIHAR_MAX_CONCURRENT: int = Field(default_factory=lambda: int(os.environ.get("BIHAR_MAX_CONCURRENT", "3")))
    BIHAR_MAX_PENDING_REQUESTS: int = Field(default_factory=lambda: int(os.environ.get("BIHAR_MAX_PENDING_REQUESTS", "10")))
    BIHAR_TIMEOUT_SECONDS: int = Field(default_factory=lambda: int(os.environ.get("BIHAR_TIMEOUT_SECONDS", "30")))
    
    # Timeout Configurations (Seconds / Milliseconds)
    ROR_TIMEOUT_SECONDS: int = Field(default_factory=lambda: int(os.environ.get("ROR_TIMEOUT_SECONDS", "90")))
    PDF_TIMEOUT_SECONDS: int = Field(default_factory=lambda: int(os.environ.get("PDF_TIMEOUT_SECONDS", "60")))
    GIS_TIMEOUT_SECONDS: int = Field(default_factory=lambda: int(os.environ.get("GIS_TIMEOUT_SECONDS", "15")))
    BHULEKH_NAVIGATION_TIMEOUT_MS: int = Field(default_factory=lambda: int(os.environ.get("BHULEKH_NAVIGATION_TIMEOUT_MS", "20000")))
    BHULEKH_ACTION_TIMEOUT_MS: int = Field(default_factory=lambda: int(os.environ.get("BHULEKH_ACTION_TIMEOUT_MS", "10000")))
    
    # Maximum Payload & File Buffers
    MAX_PDF_SIZE_BYTES: int = Field(default_factory=lambda: int(os.environ.get("MAX_PDF_SIZE_BYTES", "15728640"))) # 15 MB

    @property
    def is_production(self) -> bool:
        return self.ENV.lower() == "production"

    @property
    def is_staging(self) -> bool:
        return self.ENV.lower() == "staging"

    @property
    def is_development(self) -> bool:
        return self.ENV.lower() == "development"

    @property
    def ALLOWED_ORIGINS(self) -> List[str]:
        if self.is_production:
            return [
                "https://bhumitra.app",
                "https://api.bhumitra.app",
                "https://admin.bhumitra.app",
            ]
        return ["*"]


# Global settings singleton
settings = Settings()
