"""
Test Production Domain & Security Configuration
Validates that custom domain 'api.bhumitra.app' is properly configured in allowed origins
and production settings enforce strict HTTPS and CORS policies.
"""
import pytest
from core.config import Settings


def test_production_allowed_origins():
    prod_settings = Settings(ENV="production")
    assert prod_settings.is_production
    assert not prod_settings.is_development
    
    origins = prod_settings.ALLOWED_ORIGINS
    assert "https://api.bhumitra.app" in origins
    assert "https://bhumitra.app" in origins
    assert "https://admin.bhumitra.app" in origins
    assert "*" not in origins


def test_development_allowed_origins():
    dev_settings = Settings(ENV="development")
    assert dev_settings.is_development
    assert not dev_settings.is_production
    assert dev_settings.ALLOWED_ORIGINS == ["*"]
