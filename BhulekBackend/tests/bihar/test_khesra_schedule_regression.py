"""
Regression Test: Khesra Extraction from Plot Schedule Table
Reproduces the issue where Khesra is omitted from the top summary table and only present in the plot schedule table.
Verifies that find_field_text() does not erroneously capture adjacent <th> header text.
"""

from scrapers.bihar.bihar_jamabandi_parser import BiharJamabandiParser


def test_khesra_schedule_regression_reproduction():
    # HTML where Khesra is ONLY present in tblPlotSchedule and NOT in the top location table
    html = """
    <!DOCTYPE html>
    <html>
    <head><title>बिहार सरकार - जमाबंदी</title></head>
    <body>
    <table id="tblLocationHierarchy">
      <tr>
        <td><b>जिला:</b> PATNA</td>
        <td><b>अंचल:</b> PATNA SADAR</td>
        <td><b>मौजा:</b> BEGAMPUR</td>
        <td><b>थाना संख्या:</b> 108</td>
        <td><b>खाता संख्या:</b> 78</td>
      </tr>
    </table>

    <table id="tblRaiyatDetails">
      <thead>
        <tr><th>क्र.सं.</th><th>रैयत का नाम</th><th>पिता/पति का नाम</th></tr>
      </thead>
      <tbody>
        <tr><td>1</td><td>राम प्रसाद</td><td>श्याम नारायण</td></tr>
      </tbody>
    </table>

    <table id="tblPlotSchedule">
      <thead>
        <tr>
          <th>क्र.सं.</th>
          <th>खाता संख्या</th>
          <th>खेसरा संख्या</th>
          <th>कुल रकबा (एकड़ / डिसमिल)</th>
          <th>जमीन का किस्म</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>1</td>
          <td>78</td>
          <td>245</td>
          <td>0.375 Acre</td>
          <td>भीठ-2</td>
        </tr>
      </tbody>
    </table>
    </body>
    </html>
    """

    res = BiharJamabandiParser.parse_html(html)

    assert res.success is True
    # The plot MUST be "245" extracted from the plot schedule row, NOT the header text "कुल रकबा (एकड़ / डिसमिल)"
    assert res.plot == "245"
    assert "कुल रकबा" not in res.plot
    assert res.khata_number == "78"
    assert res.area == "0.375 Acre"
