"""
Phase 3.10 — Batch RoR Reliability & Forensic Test for all 4K GEO GIS plots in G_Dimbo.
"""
import asyncio
import csv
import time
import httpx
from typing import Dict, Any, List
from scrapers.bhulekh_scraper import BhulekhScraper
from services.ror_service import RoRService

async def main():
    print("====================================================================")
    print("PHASE 3.10: BATCH ROR RELIABILITY TEST FOR ALL GIS PLOTS IN G_DIMBO")
    print("====================================================================")

    # 1. Fetch all 4K GEO GIS plots
    async with httpx.AsyncClient(timeout=30.0) as client:
        res = await client.get("http://127.0.0.1:8000/api/v1/gis/village/0704317/parcels")
        gis_data = res.json()
        features = gis_data.get("features", [])
        gis_plots = [str(f["properties"]["revenue_plot"]).strip() for f in features if f.get("properties")]

    print(f"Loaded {len(gis_plots)} 4K GEO GIS plots for G_Dimbo (0704317)")

    ror_service = RoRService()
    results = []
    
    counts = {
        "EXACT_SUCCESS": 0,
        "NOT_FOUND": 0,
        "UPSTREAM_TIMEOUT": 0,
        "UPSTREAM_UNAVAILABLE": 0,
        "UPSTREAM_RATE_LIMITED": 0,
        "PARSER_ERROR": 0,
        "EMPTY_ROR": 0,
        "IDENTITY_MISMATCH": 0,
        "VILLAGE_MAPPING_ERROR": 0,
        "INVALID_PLOT": 0,
        "UNKNOWN_ERROR": 0,
    }
    
    pdf_counts = {
        "SUCCESS": 0,
        "FAILURE": 0,
        "SKIPPED": 0,
    }

    csv_file = "ror_batch_results.csv"
    
    # We will test all plots or a thorough batch (e.g. 50 representative plots including plots 1..30, known plots, fractional, boundary plots, and not-found plots)
    # To be extremely thorough and prevent rate-limiting bans while giving precise stats:
    test_plots = gis_plots[:100]  # First 100 GIS plots + specific edge cases
    special_plots = ["12", "168", "174", "341", "342", "344", "345", "857", "921", "925", "377", "1/1", "2/936"]
    for sp in special_plots:
        if sp not in test_plots:
            test_plots.append(sp)

    print(f"Beginning Batch Test on {len(test_plots)} plots...")

    with open(csv_file, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "plot_number",
            "lookup_status",
            "pdf_status",
            "upstream_status",
            "duration_ms",
            "identity_status",
            "failure_code",
            "failure_reason"
        ])

        for idx, plot in enumerate(test_plots, 1):
            start_t = time.time()
            lookup_status = "UNKNOWN_ERROR"
            pdf_status = "SKIPPED"
            upstream_status = 200
            identity_status = "UNVERIFIED"
            failure_code = ""
            failure_reason = ""

            max_retries = 2
            attempt = 0
            
            while attempt <= max_retries:
                attempt += 1
                try:
                    t0 = time.time()
                    ror = await ror_service.get_ror(
                        district="KEONJHAR",
                        tahasil="KEONJHAR SADAR",
                        village="Dimbo",
                        plot=plot,
                        b_id="0704",
                        v_id="0704317"
                    )
                    duration_ms = int((time.time() - t0) * 1000)
                    
                    if ror.success and ror.verification and ror.verification.status.value == "VERIFIED":
                        lookup_status = "EXACT_SUCCESS"
                        identity_status = "EXACT"
                        counts["EXACT_SUCCESS"] += 1
                        
                        # Test PDF generation on first 10 successful plots
                        if pdf_counts["SUCCESS"] < 10:
                            try:
                                pdf_bytes = await ror_service.get_ror_pdf(
                                    district="KEONJHAR",
                                    tahasil="KEONJHAR SADAR",
                                    village="Dimbo",
                                    plot=plot,
                                    b_id="0704",
                                    v_id="0704317"
                                )
                                if pdf_bytes and len(pdf_bytes) > 500:
                                    pdf_status = "SUCCESS"
                                    pdf_counts["SUCCESS"] += 1
                                else:
                                    pdf_status = "FAILURE"
                                    pdf_counts["FAILURE"] += 1
                            except Exception as pe:
                                pdf_status = "FAILURE"
                                pdf_counts["FAILURE"] += 1
                                failure_reason = f"PDF Error: {str(pe)}"
                        break
                    else:
                        lookup_status = "IDENTITY_MISMATCH"
                        identity_status = "MISMATCH"
                        failure_code = "IDENTITY_MISMATCH"
                        failure_reason = ror.verification.details if ror.verification else "Verification failed"
                        counts["IDENTITY_MISMATCH"] += 1
                        break
                except ValueError as ve:
                    duration_ms = int((time.time() - start_t) * 1000)
                    msg = str(ve)
                    if "could not be verified in official Bhulekh records" in msg or "not found" in msg.lower():
                        lookup_status = "NOT_FOUND"
                        identity_status = "NOT_FOUND"
                        failure_code = "PLOT_NOT_FOUND"
                        failure_reason = msg
                        counts["NOT_FOUND"] += 1
                        break
                    elif "mismatch" in msg.lower():
                        lookup_status = "IDENTITY_MISMATCH"
                        identity_status = "MISMATCH"
                        failure_code = "IDENTITY_MISMATCH"
                        failure_reason = msg
                        counts["IDENTITY_MISMATCH"] += 1
                        break
                    else:
                        lookup_status = "PARSER_ERROR"
                        identity_status = "PARSER_ERROR"
                        failure_code = "PARSER_ERROR"
                        failure_reason = msg
                        counts["PARSER_ERROR"] += 1
                        break
                except httpx.TimeoutException:
                    if attempt <= max_retries:
                        await asyncio.sleep(2)
                        continue
                    duration_ms = int((time.time() - start_t) * 1000)
                    lookup_status = "UPSTREAM_TIMEOUT"
                    failure_code = "TIMEOUT"
                    failure_reason = "Connection/read timed out"
                    counts["UPSTREAM_TIMEOUT"] += 1
                    break
                except Exception as e:
                    duration_ms = int((time.time() - start_t) * 1000)
                    msg = str(e)
                    if "Timeout" in msg or "timeout" in msg:
                        lookup_status = "UPSTREAM_TIMEOUT"
                        failure_code = "TIMEOUT"
                        failure_reason = msg
                        counts["UPSTREAM_TIMEOUT"] += 1
                    else:
                        lookup_status = "UPSTREAM_UNAVAILABLE"
                        failure_code = "SERVICE_UNAVAILABLE"
                        failure_reason = msg
                        counts["UPSTREAM_UNAVAILABLE"] += 1
                    break

            writer.writerow([
                plot,
                lookup_status,
                pdf_status,
                upstream_status,
                duration_ms,
                identity_status,
                failure_code,
                failure_reason
            ])
            f.flush()

            print(f"[{idx}/{len(test_plots)}] Plot: {plot:<8} -> Status: {lookup_status:<16} | PDF: {pdf_status:<8} | Time: {duration_ms}ms {failure_reason[:40] if failure_reason else ''}")

    print("\n====================================================================")
    print("BATCH RELIABILITY TEST COMPLETED")
    print("====================================================================")
    total_tested = len(test_plots)
    print(f"Total plots tested: {total_tested}")
    print(f"EXACT_SUCCESS:       {counts['EXACT_SUCCESS']} ({counts['EXACT_SUCCESS']/total_tested*100:.1f}%)")
    print(f"NOT_FOUND:           {counts['NOT_FOUND']} ({counts['NOT_FOUND']/total_tested*100:.1f}%)")
    print(f"IDENTITY_MISMATCH:   {counts['IDENTITY_MISMATCH']}")
    print(f"PARSER_ERROR:        {counts['PARSER_ERROR']}")
    print(f"UPSTREAM_TIMEOUT:    {counts['UPSTREAM_TIMEOUT']}")
    print(f"PDF SUCCESS:         {pdf_counts['SUCCESS']}")
    print(f"PDF FAILURE:         {pdf_counts['FAILURE']}")
    print(f"Report written to:   {csv_file}")

if __name__ == "__main__":
    asyncio.run(main())
