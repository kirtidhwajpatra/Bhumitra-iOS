"""
Remote Configuration Service
Loads, caches, and persists dynamic application configuration and feature flags
in PostgreSQL (app_configs table) with safe default fallbacks.
"""

import json
import time
from datetime import datetime, timezone
from typing import Optional

from db.session import get_db_session
from models.db_models import AppConfigDB
from models.config_models import (
    AppConfigResponse,
    AppConfigUpdateRequest,
    FeaturesConfig,
    PaywallConfig,
)

CONFIG_DB_KEY = "global_remote_config"


class ConfigService:
    def __init__(self):
        self._cached_config: Optional[AppConfigResponse] = None
        self._cache_timestamp: float = 0
        self._cache_ttl: float = 10.0  # 10 second internal backend cache

    def _get_default_config(self) -> AppConfigResponse:
        """Safe default production configuration."""
        return AppConfigResponse(
            config_version=1,
            server_time=datetime.now(timezone.utc).isoformat(),
            ttl_seconds=3600,
            min_supported_version="1.0.0",
            recommended_version="1.0.0",
            latest_version="1.0.0",
            app_store_id="6742337788",
            app_store_url="https://apps.apple.com/app/bhumitra-odisha-land-records/id6742337788",
            maintenance_mode=False,
            maintenance_message=None,
            subscription_enabled=True,
            premium_enabled=True,
            map_data_version="2026-08-18",
            features=FeaturesConfig(
                advanced_search=True,
                property_history=False,
                valuation=False,
                pdf_download=True,
                satellite_view=True,
            ),
            paywall=PaywallConfig(
                headline="Upgrade to Bhumitra Premium",
                subheadline="Unlock complete GIS tools, legal ROR ownership records, and official PDF downloads",
                default_tier="bhumitra_premium_yearly",
                available_tiers=[
                    "bhumitra_premium_monthly",
                    "bhumitra_premium_yearly",
                    "bhumitra_premium_lifetime",
                ],
            ),
        )

    def get_active_config(self) -> AppConfigResponse:
        """
        Retrieves the active remote configuration from PostgreSQL or memory cache.
        Falls back safely to default config if database is empty or unreachable.
        """
        now = time.time()
        if self._cached_config and (now - self._cache_timestamp) < self._cache_ttl:
            # Return cached config with refreshed server_time
            cached = self._cached_config.model_copy()
            cached.server_time = datetime.now(timezone.utc).isoformat()
            return cached

        try:
            with get_db_session() as session:
                row = session.query(AppConfigDB).filter(AppConfigDB.key == CONFIG_DB_KEY).first()
                if row and row.value:
                    data = json.loads(row.value)
                    config = AppConfigResponse(**data)
                    config.server_time = datetime.now(timezone.utc).isoformat()
                    self._cached_config = config
                    self._cache_timestamp = now
                    return config
                else:
                    # Initialize default config in DB
                    default_config = self._get_default_config()
                    new_row = AppConfigDB(
                        key=CONFIG_DB_KEY,
                        value=default_config.model_dump_json(),
                    )
                    session.add(new_row)
                    session.commit()
                    self._cached_config = default_config
                    self._cache_timestamp = now
                    return default_config
        except Exception as e:
            print(f"Warning: Could not fetch remote config from DB: {e}. Using fallback defaults.")
            default_config = self._get_default_config()
            return default_config

    def update_config(self, update: AppConfigUpdateRequest) -> AppConfigResponse:
        """
        Updates and persists new configuration values in PostgreSQL, incrementing config_version.
        """
        now_dt = datetime.now(timezone.utc)
        now_ts = time.time()

        with get_db_session() as session:
            row = session.query(AppConfigDB).filter(AppConfigDB.key == CONFIG_DB_KEY).first()
            if row and row.value:
                current_data = json.loads(row.value)
                current_config = AppConfigResponse(**current_data)
            else:
                current_config = self._get_default_config()
                row = AppConfigDB(key=CONFIG_DB_KEY, value="")
                session.add(row)

            # Apply fields that were provided in the update request
            updated_dict = current_config.model_dump()
            update_data = update.model_dump(exclude_unset=True)

            for key, val in update_data.items():
                if val is not None:
                    updated_dict[key] = val

            # Increment config version and refresh timestamp
            updated_dict["config_version"] = current_config.config_version + 1
            updated_dict["server_time"] = now_dt.isoformat()

            new_config = AppConfigResponse(**updated_dict)
            row.value = new_config.model_dump_json()
            row.updated_at = now_dt
            session.commit()

            # Refresh cache
            self._cached_config = new_config
            self._cache_timestamp = now_ts

            print(f"DEBUG: ⚙️ [Config] Remote Config updated to v{new_config.config_version}. Maintenance: {new_config.maintenance_mode}, Min Version: {new_config.min_supported_version}")
            return new_config


config_service = ConfigService()
