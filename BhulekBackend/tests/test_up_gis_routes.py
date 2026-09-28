"""
Route tests for the UP map-layer prototype (/api/v1/gis/up/*).
The provider is replaced with a fake; no network.
"""
import pytest
from fastapi.testclient import TestClient

from app import create_app
from core.config import settings
from models.up_gis import UPLevelItem, UPPlotRecord, UPPlotResult, UPVillageExtent
from providers.up_bhunaksha_provider import UPNotFound, UPUpstreamUnavailable
from routers.up_gis import get_up_provider

GIS = "15900830145758"
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32


class FakeProvider:
    def __init__(self):
        self.calls = []

    async def list_level(self, level, parents):
        self.calls.append(("levels", level, tuple(parents)))
        return [UPLevelItem(code="159", name="फर्रूखाबाद")]

    async def village_extent(self, d, t, v):
        if v == "000000":
            raise UPNotFound("No georeferenced map is available for this village.")
        return UPVillageExtent(gis_code=GIS, district_code=d, tehsil_code=t, village_code=v,
                               crs="EPSG:32644", utm_bbox=[1, 2, 3, 4],
                               bbox=[79.358, 27.460, 79.386, 27.481], center_lat=27.47, center_lng=79.372)

    async def identify(self, gis, lat, lng):
        return UPPlotResult(gis_code=gis, plot_no="522", bbox=[79.37, 27.47, 79.371, 27.471],
                            records=[UPPlotRecord(khata_no="00007", plot_no="522/2", area=0.162, area_unit="Hectare")])

    async def plot_by_number(self, gis, plot_no):
        raise UPUpstreamUnavailable("UP BhuNaksha did not respond in time.")

    async def wms_tile(self, gis, bbox, size=256):
        self.calls.append(("wms", gis, tuple(bbox), size))
        if gis == "00000000000000":
            raise UPNotFound("empty")
        return PNG


@pytest.fixture
def fake():
    return FakeProvider()


@pytest.fixture
def client(fake, monkeypatch):
    monkeypatch.setattr(settings, "UP_GIS_PROVIDER_ENABLED", True)
    app = create_app()
    app.dependency_overrides[get_up_provider] = lambda: fake
    with TestClient(app) as c:
        yield c


def test_all_routes_fail_closed_when_disabled(fake, monkeypatch):
    monkeypatch.setattr(settings, "UP_GIS_PROVIDER_ENABLED", False)
    app = create_app()
    app.dependency_overrides[get_up_provider] = lambda: fake
    with TestClient(app) as c:
        for url in [
            "/api/v1/gis/up/levels?level=1",
            "/api/v1/gis/up/village/extent?district=159&tehsil=00830&village=145758",
            f"/api/v1/gis/up/identify?gis_code={GIS}&lat=27.47&lng=79.37",
            f"/api/v1/gis/up/plot?gis_code={GIS}&plot_no=522",
            f"/api/v1/gis/up/wms/{GIS}?bbox=1,2,3,4",
        ]:
            r = c.get(url)
            assert r.status_code == 503, url
            assert r.json()["error_code"] == "UP_GIS_DISABLED"
        assert c.get("/api/v1/gis/up/health").json()["enabled"] is False
    assert fake.calls == []


def test_levels(client, fake):
    r = client.get("/api/v1/gis/up/levels?level=2&codes=159")
    assert r.status_code == 200
    body = r.json()
    assert body["label"] == "Tehsil" and body["items"][0]["code"] == "159"
    assert fake.calls[-1] == ("levels", 2, ("159",))


def test_levels_rejects_bad_level(client):
    assert client.get("/api/v1/gis/up/levels?level=4").status_code == 422


def test_village_extent_and_not_found(client):
    ok = client.get("/api/v1/gis/up/village/extent?district=159&tehsil=00830&village=145758")
    assert ok.status_code == 200 and ok.json()["gis_code"] == GIS
    nf = client.get("/api/v1/gis/up/village/extent?district=159&tehsil=00830&village=000000")
    assert nf.status_code == 404 and nf.json()["error_code"] == "UP_NOT_FOUND"


def test_identify_returns_records_only(client):
    r = client.get(f"/api/v1/gis/up/identify?gis_code={GIS}&lat=27.47&lng=79.37")
    assert r.status_code == 200
    body = r.json()
    assert body["plot_no"] == "522" and body["records"][0]["khata_no"] == "00007"
    assert set(body["records"][0]) == {"khata_no", "plot_no", "area", "area_unit"}
    assert body["official_record_url"].startswith("https://upbhulekh.gov.in")


def test_plot_upstream_unavailable_is_503(client):
    r = client.get(f"/api/v1/gis/up/plot?gis_code={GIS}&plot_no=522")
    assert r.status_code == 503 and r.json()["retryable"] is True


def test_wms_returns_png(client, fake):
    r = client.get(f"/api/v1/gis/up/wms/{GIS}?bbox=8834000,3181000,8836000,3183000")
    assert r.status_code == 200
    assert r.headers["content-type"] == "image/png"
    assert "max-age" in r.headers["cache-control"]
    assert r.content.startswith(b"\x89PNG")
    assert fake.calls[-1] == ("wms", GIS, (8834000.0, 3181000.0, 8836000.0, 3183000.0), 256)


def test_wms_bad_bbox_and_empty(client):
    assert client.get(f"/api/v1/gis/up/wms/{GIS}?bbox=1,2,3").status_code == 422
    assert client.get(f"/api/v1/gis/up/wms/{GIS}?bbox=a,b,c,d").status_code == 422
    assert client.get("/api/v1/gis/up/wms/00000000000000?bbox=8834000,3181000,8836000,3183000").status_code == 204


def test_app_config_exposes_up_flag(client):
    r = client.get("/api/v1/app-config")
    assert r.status_code == 200
    assert r.json()["up_map_enabled"] is False
