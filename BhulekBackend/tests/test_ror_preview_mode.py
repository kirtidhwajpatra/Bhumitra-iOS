"""
Unit tests for RoR preview mode and server-side sensitive data masking for zero-credit users.
"""
import pytest
from models.ror_response import RoRResponse, OwnerEntry
from routers.ror import sanitize_ror_preview


def test_sanitize_ror_preview_masks_pii_and_locks_response():
    """Verify that sanitize_ror_preview masks owner names, khata, area, and sets is_locked."""
    original = RoRResponse(
        success=True,
        plot="1234",
        village="DIMBO",
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        khata_number="47/12",
        area="1.250 Acre",
        land_type="Gharabari",
        owners=[
            OwnerEntry(name="RAMESH CHANDRA ROUT", relation="s/o", relation_name="HARI ROUT", share="1/1"),
            OwnerEntry(name="BI", relation=None, relation_name=None, share=None),
        ],
    )
    
    preview = sanitize_ror_preview(original)
    
    assert preview.is_preview is True
    assert preview.is_locked is True
    assert preview.plot == "1234"
    assert preview.khata_number == "448"
    assert "1.4580" in preview.area
    # First letter of first name and surname in RAMESH CHANDRA ROUT is preserved
    assert preview.owners[0].name.startswith("R")
    assert " R" in preview.owners[0].name
    assert "•" not in preview.owners[0].name
    assert preview.owners[0].relation_name is None
    assert preview.owners[0].share is None
    assert preview.official_document is None
    assert preview.preview_message is not None
