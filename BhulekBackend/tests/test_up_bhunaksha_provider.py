"""
Unit tests for the Uttar Pradesh BhuNaksha provider (map-layer prototype).
Upstream is mocked with httpx.MockTransport; response shapes mirror what the
live portal returned on 2026-09-28. Owner names in fixtures are fictional.
"""
import json
import urllib.parse

import httpx
import pytest

from providers.up_bhunaksha_provider import (
    UPBhunakshaProvider,
    UPInvalidInput,
    UPNotFound,
    UPUpstreamUnavailable,
    latlng_to_utm,
    parse_plot_info,
    split_gis_code,
    utm_bbox_to_latlng_bbox,
    utm_to_latlng,
)

GIS = "15900830145758"
EXTENT = {
    "xmin": 337764.49483522936, "ymin": 3038483.64874887,
    "xmax": 340550.6057938953, "ymax": 3040773.1618689657,
    "attribution": None, "scaleFactor": 1.0, "crs": "EPSG:32644", "gisCode": GIS,
}
PLOT = {
    "miny": 3039485.957163467, "minx": 339110.0798684845, "bhucode": GIS,
    "maxy": 3039648.300415968, "maxx": 339173.1269537543,
    "id": "0YfuyhOOSEW8CsVnSYayfQ", "kide": "522",
}
PLOT_INFO_TEXT = (
    "Khata No: 00007   Plot No: 522/2    Area : 0.1620 Hectare\n"
    "Khata No: 00282   Plot No: 522/4    Area : 0.1210 Hectare\n"
    "Khata No: 00380   Plot No: 522मि    Area : 0.0200 Hectare\n"
    "Owner Details For Khata No.:- 00007\n"
    "1 :-  नाम :   परीक्षण व्यक्ति     संरक्षक का नाम : नमूना पिता     निवास स्थान : नि.ग्राम\n"
    "2 :-  नाम :   दूसरा परीक्षण     संरक्षक का नाम : नमूना पिता     निवास स्थान : नि.ग्राम\n"
    "Owner Details For Khata No.:- 00282\n"
    "1 :-  नाम :   तीसरा परीक्षण     संरक्षक का नाम : अन्य     निवास स्थान : नि.ग्राम\n"
)
LEVEL1 = [
    {"code": "159", "value": "फर्रूखाबाद", "extraParams": {"hasData": True}},
    {"code": "999", "value": "बिना डेटा", "extraParams": {"hasData": False}},
    {"code": "160", "value": "कन्नौज", "extraParams": {"hasData": True}},
]
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64


def make_provider(handler, calls=None):
    def wrapped(request: httpx.Request):
        if calls is not None:
            calls.append(request)
        return handler(request)
    return UPBhunakshaProvider(base_url="https://up.test/bhunakshaserver",
                               transport=httpx.MockTransport(wrapped))


def form(request: httpx.Request) -> dict:
    return dict(urllib.parse.parse_qsl(request.content.decode(), keep_blank_values=True))


def happy_handler(request: httpx.Request) -> httpx.Response:
    path = request.url.path
    if path.endswith("/masterdata/levelvalue"):
        return httpx.Response(200, json=LEVEL1)
    if path.endswith("/MapInfo/getVVVVExtentGeoref"):
        return httpx.Response(200, json=EXTENT)
    if path.endswith("/MapInfo/getPlotAtXY") or path.endswith("/MapInfo/getPlotByPlotNo"):
        return httpx.Response(200, json=PLOT)
    if path.endswith("/MapInfo/getPlotInfo"):
        return httpx.Response(200, text=PLOT_INFO_TEXT)
    if path.endswith("/WMS"):
        return httpx.Response(200, content=PNG, headers={"Content-Type": "image/png"})
    return httpx.Response(404)


# ---------------------------------------------------------------- math

def test_utm_to_latlng_matches_verified_sample():
    lat, lng = utm_to_latlng(337764.49, 3038483.65, 44)
    assert lat == pytest.approx(27.46023, abs=1e-4)
    assert lng == pytest.approx(79.35820, abs=1e-4)


def test_utm_round_trip_is_sub_metre():
    for lat, lng in [(27.47, 79.37), (25.4069, 82.9792), (29.01, 78.50)]:
        x, y = latlng_to_utm(lat, lng, 44)
        lat2, lng2 = utm_to_latlng(x, y, 44)
        assert abs(lat2 - lat) < 1e-6 and abs(lng2 - lng) < 1e-6


def test_bbox_conversion_contains_all_corners():
    bbox = utm_bbox_to_latlng_bbox(337764.49, 3038483.65, 340550.61, 3040773.16, 44)
    assert bbox[0] < bbox[2] and bbox[1] < bbox[3]
    assert bbox[1] == pytest.approx(27.46, abs=0.01)


def test_split_gis_code():
    assert split_gis_code(GIS) == ("159", "00830", "145758")
    assert split_gis_code("123") is None


# ---------------------------------------------------------------- parsing

def test_parse_plot_info_extracts_records_and_drops_owners():
    records = parse_plot_info(PLOT_INFO_TEXT)
    assert [(r.khata_no, r.plot_no) for r in records] == [
        ("00007", "522/2"), ("00282", "522/4"), ("00380", "522मि"),
    ]
    assert records[0].area == pytest.approx(0.162)
    assert records[0].area_unit == "Hectare"
    dumped = json.dumps([r.model_dump() for r in records], ensure_ascii=False)
    for fragment in ("परीक्षण", "नाम", "संरक्षक", "Owner"):
        assert fragment not in dumped


def test_parse_plot_info_handles_empty_and_garbage():
    assert parse_plot_info("") == []
    assert parse_plot_info("<html>error</html>") == []


# ---------------------------------------------------------------- provider

@pytest.mark.anyio
async def test_list_level_filters_no_data_and_caches():
    calls = []
    p = make_provider(happy_handler, calls)
    items = await p.list_level(1, [])
    assert [i.code for i in items] == ["159", "160"]
    await p.list_level(1, [])
    assert len(calls) == 1
    assert form(calls[0]) == {"level": "1", "codes": ""}


@pytest.mark.anyio
async def test_list_level_validates_parent_codes():
    p = make_provider(happy_handler)
    with pytest.raises(UPInvalidInput):
        await p.list_level(2, [])
    with pytest.raises(UPInvalidInput):
        await p.list_level(3, ["159", "abc"])
    with pytest.raises(UPInvalidInput):
        await p.list_level(4, ["1", "2", "3"])


@pytest.mark.anyio
async def test_village_extent_converts_to_wgs84():
    p = make_provider(happy_handler)
    ext = await p.village_extent("159", "00830", "145758")
    assert ext.gis_code == GIS and ext.crs == "EPSG:32644"
    assert ext.center_lat == pytest.approx(27.4707, abs=1e-3)
    assert ext.center_lng == pytest.approx(79.3722, abs=1e-3)


@pytest.mark.anyio
async def test_village_extent_not_georeferenced_is_not_found():
    p = make_provider(lambda r: httpx.Response(200, json={"xmin": None, "gisCode": GIS}))
    with pytest.raises(UPNotFound):
        await p.village_extent("159", "00830", "145758")


@pytest.mark.anyio
async def test_identify_sends_utm_and_returns_records_without_owners():
    calls = []
    p = make_provider(happy_handler, calls)
    plot = await p.identify(GIS, 27.4702, 79.3718)
    assert plot.plot_no == "522"
    assert len(plot.records) == 3
    assert plot.bbox[0] < plot.bbox[2]
    xy = next(form(c) for c in calls if c.url.path.endswith("/getPlotAtXY"))
    assert xy["giscode"] == GIS
    assert 339000 < float(xy["x"]) < 339300 and 3039400 < float(xy["y"]) < 3039700
    info_call = next(c for c in calls if c.url.path.endswith("/getPlotInfo"))
    assert json.loads(info_call.content) == {"gisCode": GIS, "plotNo": "522"}
    assert "परीक्षण" not in plot.model_dump_json()


@pytest.mark.anyio
async def test_identify_outside_up_is_rejected():
    p = make_provider(happy_handler)
    with pytest.raises(UPInvalidInput):
        await p.identify(GIS, 20.3, 85.8)  # Bhubaneswar


@pytest.mark.anyio
async def test_identify_empty_response_is_not_found():
    def handler(r):
        if r.url.path.endswith("/getPlotAtXY"):
            return httpx.Response(200, content=b"")
        return happy_handler(r)
    p = make_provider(handler)
    with pytest.raises(UPNotFound):
        await p.identify(GIS, 27.47, 79.37)


@pytest.mark.anyio
async def test_identify_survives_plot_info_failure():
    def handler(r):
        if r.url.path.endswith("/getPlotInfo"):
            return httpx.Response(500, json={"status": "500"})
        return happy_handler(r)
    p = make_provider(handler)
    plot = await p.identify(GIS, 27.47, 79.37)
    assert plot.plot_no == "522" and plot.records == []


@pytest.mark.anyio
async def test_plot_by_number_validates_input():
    p = make_provider(happy_handler)
    with pytest.raises(UPInvalidInput):
        await p.plot_by_number(GIS, "")
    with pytest.raises(UPInvalidInput):
        await p.plot_by_number(GIS, "1; DROP")
    plot = await p.plot_by_number(GIS, "522")
    assert plot.plot_no == "522"


@pytest.mark.anyio
async def test_timeout_maps_to_unavailable():
    def handler(r):
        raise httpx.ReadTimeout("slow", request=r)
    p = make_provider(handler)
    with pytest.raises(UPUpstreamUnavailable):
        await p.list_level(1, [])


@pytest.mark.anyio
async def test_upstream_5xx_maps_to_unavailable():
    p = make_provider(lambda r: httpx.Response(502))
    with pytest.raises(UPUpstreamUnavailable):
        await p.village_extent("159", "00830", "145758")


@pytest.mark.anyio
async def test_wms_tile_returns_png_and_caches():
    calls = []
    p = make_provider(happy_handler, calls)
    bbox = [8834000.0, 3181000.0, 8836000.0, 3183000.0]
    body = await p.wms_tile(GIS, bbox)
    assert body.startswith(b"\x89PNG")
    await p.wms_tile(GIS, bbox)
    assert len(calls) == 1
    q = dict(calls[0].url.params)
    assert q["SRS"] == "EPSG:3857" and q["gis_code"] == GIS and q["LAYERS"] == "VILLAGE_MAP"


@pytest.mark.anyio
async def test_wms_tile_rejects_bad_bbox_and_non_png():
    p = make_provider(happy_handler)
    with pytest.raises(UPInvalidInput):
        await p.wms_tile(GIS, [2.0, 2.0, 1.0, 1.0])
    p2 = make_provider(lambda r: httpx.Response(200, text="<html>nope</html>"))
    with pytest.raises(Exception):
        await p2.wms_tile(GIS, [1.0, 1.0, 2.0, 2.0])


def test_parse_plot_info_rejects_owner_text_embedded_in_record_line():
    adversarial = (
        "Khata No: 7 Plot No: 522 Owner: Alice Area: 0.1000 Hectare\n"
        "Khata No: 8 Plot No: 523 नाम : परीक्षण Area: 0.2000 Hectare"
    )
    assert parse_plot_info(adversarial) == []


@pytest.mark.anyio
async def test_plot_identity_rejects_unrestricted_upstream_text():
    tainted = dict(PLOT, kide="522 Owner Alice", id="id owner Alice")
    def handler(request):
        if request.url.path.endswith("/getPlotAtXY"):
            return httpx.Response(200, json=tainted)
        return happy_handler(request)
    p = make_provider(handler)
    with pytest.raises(UPNotFound):
        await p.identify(GIS, 27.47, 79.37)


@pytest.mark.anyio
@pytest.mark.parametrize("bbox", [
    [float("-inf"), 3_181_000.0, float("inf"), 3_183_000.0],
    [8_834_000.0, 3_181_000.0, 8_934_000.0, 3_281_000.0],
    [1.0, 1.0, 2.0, 2.0],
    [8_834_000.0, 3_181_000.0, 8_834_001.0, 3_181_001.0],
])
async def test_wms_rejects_nonfinite_unbounded_or_non_tile_bbox(bbox):
    p = make_provider(happy_handler)
    with pytest.raises(UPInvalidInput):
        await p.wms_tile(GIS, bbox)


@pytest.mark.anyio
async def test_wms_response_has_hard_byte_cap():
    from providers.up_bhunaksha_provider import UPResponseTooLarge
    huge = b"\x89PNG\r\n\x1a\n" + b"x" * (512 * 1024)
    p = make_provider(lambda r: httpx.Response(200, content=huge))
    with pytest.raises(UPResponseTooLarge):
        await p.wms_tile(GIS, [8_834_000.0, 3_181_000.0, 8_836_000.0, 3_183_000.0])


@pytest.mark.anyio
async def test_wms_cache_obeys_byte_budget(monkeypatch):
    import providers.up_bhunaksha_provider as module
    monkeypatch.setattr(module, "_TILE_CACHE_BYTES", len(PNG) + 4)
    p = make_provider(happy_handler)
    await p.wms_tile(GIS, [8_834_000.0, 3_181_000.0, 8_836_000.0, 3_183_000.0])
    await p.wms_tile(GIS, [8_836_000.0, 3_181_000.0, 8_838_000.0, 3_183_000.0])
    assert p._tile_cache_bytes <= module._TILE_CACHE_BYTES
    assert len(p._tile_cache) == 1


@pytest.mark.anyio
async def test_invalid_upstream_extent_is_controlled_error():
    bad = dict(EXTENT, xmin=float("nan"))
    p = make_provider(lambda r: httpx.Response(200, content=json.dumps(bad, allow_nan=True).encode()))
    from providers.up_bhunaksha_provider import UPBhunakshaError
    with pytest.raises(UPBhunakshaError):
        await p.village_extent("159", "00830", "145758")
