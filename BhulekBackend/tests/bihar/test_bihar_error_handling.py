"""
Bihar Error Handling & Fault Resilience Test Suite
Tests parser reaction to empty HTML, captcha challenges, missing records,
malformed HTML, partial responses, and unparseable documents.
"""

from scrapers.bihar.bihar_jamabandi_parser import BiharJamabandiParser
from models.ror_response import RoRErrorCode


def test_empty_html_handling():
    res = BiharJamabandiParser.parse_html(
        html_content="",
        requested_district="PATNA",
        requested_anchal="PATNA SADAR",
        requested_village="BEGAMPUR",
        requested_plot="245",
    )
    assert res.success is False
    assert res.error is not None
    assert res.error.code == RoRErrorCode.PARSE_FAILED


def test_captcha_challenge_handling():
    captcha_html = """
    <html><body>
    <div id="captchaBox">
      <input type="text" id="txtCaptcha" />
      <p>कृपया कैप्चा दर्ज करें</p>
    </div>
    </body></html>
    """
    res = BiharJamabandiParser.parse_html(
        html_content=captcha_html,
        requested_district="PATNA",
        requested_plot="245",
    )
    assert res.success is False
    assert res.error is not None
    assert res.error.code == RoRErrorCode.BHULEKH_TEMPORARILY_UNAVAILABLE
    assert res.error.retryable is True


def test_record_not_found_handling():
    empty_html = """
    <html><body>
    <div class="alert">कोई रिकॉर्ड नहीं मिला।</div>
    </body></html>
    """
    res = BiharJamabandiParser.parse_html(
        html_content=empty_html,
        requested_district="PATNA",
        requested_plot="9999",
    )
    assert res.success is False
    assert res.error is not None
    assert res.error.code == RoRErrorCode.PLOT_NOT_FOUND
    assert res.error.retryable is False


def test_malformed_html_does_not_crash():
    malformed_html = "<html><body><table><tr><td>unclosed tags... <span>broken"
    res = BiharJamabandiParser.parse_html(
        html_content=malformed_html,
        requested_district="PATNA",
        requested_plot="123",
    )
    # Must return a valid response object without raising an unhandled exception
    assert res is not None
    assert res.plot == "123"
