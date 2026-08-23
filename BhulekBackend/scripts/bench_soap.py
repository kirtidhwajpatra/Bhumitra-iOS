#!/usr/bin/env python3
import asyncio
import time
from resolvers.bhulekh_soap_resolver import resolve_khata_for_plot_soap

async def bench():
    t0 = time.time()
    khata = await resolve_khata_for_plot_soap("20", "2", "359", "333")
    t1 = time.time()
    print(f"Result: {khata} in {t1 - t0:.2f}s")

if __name__ == "__main__":
    asyncio.run(bench())
