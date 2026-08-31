# Bihar Land Records 30-Record Ground Truth Validation Matrix

## 1. Validation Benchmark Strategy

This validation matrix defines the target 30-record empirical benchmark for certifying the Bihar provider. Each case evaluates identity preservation, area conversion concordance, owner parsing integrity, land classification, and statutory government-land detection across 5 major Bihar administrative divisions.

**Certification Threshold**: $\ge 99\%$ concordance across all 30 benchmarks required before promoting Bihar provider from `EXPERIMENTAL` to `STAGING`.

---

## 2. 30-Record Ground Truth Evaluation Matrix

| Case ID | District | Circle (Anchal) | Village (Mauza) | Khata | Khesra | Official Portal Result | Bhumitra Normalized Result | Match Status | Validation Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **BHR-GT-01** | PATNA | PATNA SADAR | BEGAMPUR | 78 | 245 | Ram Prasad (Father: Shyam Narayan), 0.375 Acre, Bhit-2 | Plot: 245, Area: 0.375 Acre, 1 Owner, Bhit-2 | **PENDING LIVE AUDIT** | Standard single-owner private holding. |
| **BHR-GT-02** | GAYA | BODHGAYA | BAKRAUR | 115 | 89 | Suresh Kumar & Mahesh Kumar (1/2 each), 50 Decimals, Dhanhar-1 | Plot: 89, Area: 0.500 Acre, 2 Owners, Dhanhar-1 | **PENDING LIVE AUDIT** | Joint brother tenancy with equal shares. |
| **BHR-GT-03** | MUZAFFARPUR | KANTI | DAMODARPUR | 204 | 501 | Suresh Kumar & Anita Devi (Wife), 25 Decimals, Bhit-1 | Plot: 501, Area: 0.250 Acre, 2 Owners, Bhit-1 | **PENDING LIVE AUDIT** | Spousal joint tenancy (Husband relation). |
| **BHR-GT-04** | BHAGALPUR | KAHALGAON | SHIVNARAYANPUR | 93 | 614 | Kailash Prasad Mandal, 0 Bigha 12 Katha 0 Dhur, Bhit-2 | Plot: 614, Area: 0.375 Acre, 1 Owner, Bhit-2 | **PENDING LIVE AUDIT** | Traditional Bigha-Katha conversion. |
| **BHR-GT-05** | DARBHANGA | BAHADURPUR | DEKULI | 310 | 101 | Rakesh Jha, 0.250 Acre (Multi-plot: 101, 102, 103) | Plot: 101, Area: 0.250 Acre, 3 Plots associated | **PENDING LIVE AUDIT** | Multi-plot schedule within single Jamabandi. |
| **BHR-GT-06** | PATNA | PATNA SADAR | BEGAMPUR | 1 | 1020 | Bihar Sarkar, 1.500 Acre, Gairmajarua Aam (Pokhar) | Plot: 1020, Area: 1.500 Acre, Govt=True | **PENDING LIVE AUDIT** | Public common water body. |
| **BHR-GT-07** | GAYA | BODHGAYA | BAKRAUR | 2 | 450 | Anabad Bihar Sarkar, 3.200 Acre, Gairmajarua Khas | Plot: 450, Area: 3.200 Acre, Govt=True | **PENDING LIVE AUDIT** | State-owned uncultivated land. |
| **BHR-GT-08** | MUZAFFARPUR | KANTI | DAMODARPUR | 5 | 312 | Kaisar-e-Hind, 5.000 Acre, Central Govt Property | Plot: 312, Area: 5.000 Acre, Govt=True | **PENDING LIVE AUDIT** | Union property statutory classification. |
| **BHR-GT-09** | BHAGALPUR | KAHALGAON | SHIVNARAYANPUR | 10 | 777 | East Central Railway, 10.500 Acre, Railway | Plot: 777, Area: 10.500 Acre, Govt=True | **PENDING LIVE AUDIT** | Public railway infrastructure. |
| **BHR-GT-10** | DARBHANGA | BAHADURPUR | DEKULI | 12 | 890 | Public Road / PWD, 0.850 Acre, Sadak | Plot: 890, Area: 0.850 Acre, Govt=True | **PENDING LIVE AUDIT** | Road infrastructure land. |
| **BHR-GT-11** | PATNA | PHULWARI SHARIF | NOHSA | 15 | 654 | Bihar Sarkar, 2.100 Acre, Water Reservoir (Ahar/Pyne) | Plot: 654, Area: 2.100 Acre, Govt=True | **PENDING LIVE AUDIT** | Traditional irrigation reservoir. |
| **BHR-GT-12** | GAYA | MANPUR | BUNYADGANJ | 18 | 432 | Public Kabristan / Sarvsadharan, 1.250 Acre | Plot: 432, Area: 1.250 Acre, Govt=True | **PENDING LIVE AUDIT** | Public religious amenity holding. |
| **BHR-GT-13** | MUZAFFARPUR | MUSHAHARI | SHEIKHPURA | 250 | 911 | Ashok Kumar, 10 Decimals, Basgit / Makan | Plot: 911, Area: 0.100 Acre, 1 Owner, Basgit | **PENDING LIVE AUDIT** | Homestead residential parcel. |
| **BHR-GT-14** | PATNA | DANAPUR | KHAGAUL | 420 | 318 | Sanjay Agrawal, 15 Decimals, Commercial Shop | Plot: 318, Area: 0.150 Acre, 1 Owner, Commercial | **PENDING LIVE AUDIT** | Urban commercial shop classification. |
| **BHR-GT-15** | BHAGALPUR | PIRPAINTI | ROSHANPUR | 180 | 540 | Manoj Choudhary, 1.750 Acre, Orchard (Mango/Litchi) | Plot: 540, Area: 1.750 Acre, 1 Owner, Orchard | **PENDING LIVE AUDIT** | Agricultural orchard parcel. |
| **BHR-GT-16** | DARBHANGA | KEOTI | RANIPUR | 220 | 812 | Deepak Kumar Jha, 0.600 Acre, Parti Kadim | Plot: 812, Area: 0.600 Acre, 1 Owner, Fallow | **PENDING LIVE AUDIT** | Long-term fallow agricultural land. |
| **BHR-GT-17** | GAYA | FATEHPUR | GURPA | 330 | 701 | Ravindra Kumar, 40 Decimals, Bhit-1 | Plot: 701, Area: 0.400 Acre, 1 Owner, Bhit-1 | **PENDING LIVE AUDIT** | Upland fertile arable land. |
| **BHR-GT-18** | MUZAFFARPUR | SAKRA | DHOBAI | 345 | 419 | Ranjeet Kumar, 65 Decimals, Dhanhar-1 | Plot: 419, Area: 0.650 Acre, 1 Owner, Dhanhar-1 | **PENDING LIVE AUDIT** | Lowland high-yield paddy soil. |
| **BHR-GT-19** | PATNA | BIHTA | RAGHOPUR | 360 | 602 | Santosh Kumar, 48 Decimals, Dhanhar-2 | Plot: 602, Area: 0.480 Acre, 1 Owner, Dhanhar-2 | **PENDING LIVE AUDIT** | Medium grade lowland agricultural plot. |
| **BHR-GT-20** | BHAGALPUR | SULTANGANJ | ABHAYPUR | 375 | 815 | Pramod Sah, 32 Decimals, Dhanhar-3 | Plot: 815, Area: 0.320 Acre, 1 Owner, Dhanhar-3 | **PENDING LIVE AUDIT** | Standard single-crop paddy field. |
| **BHR-GT-21** | DARBHANGA | JALE | KATRA | 410 | 520 | Amit Kumar (Father: Late Brajkishore Jha), 0.450 Acre | Plot: 520, Area: 0.450 Acre, 1 Owner, Father parsed | **PENDING LIVE AUDIT** | Deceased parent honorific parsing. |
| **BHR-GT-22** | PATNA | FATUHA | SURJANPUR | 430 | 670 | Vikas Kumar (1/4 Share), 20 Decimals, Bhit-1 | Plot: 670, Area: 0.200 Acre, Share: 1/4 | **PENDING LIVE AUDIT** | Fractional holding normalization. |
| **BHR-GT-23** | GAYA | SHERGHATI | HAMZAPUR | 450 | 780 | Gopal Prasad, 0 Bigha 15 Katha 0 Dhur, Bhit-2 | Plot: 780, Area: 0.469 Acre, Traditional units | **PENDING LIVE AUDIT** | Traditional 15 Katha calculation (0.46875 Acre). |
| **BHR-GT-24** | MUZAFFARPUR | MOTIPUR | BARURAJ | 470 | 999 | Naval Kishore, 1.5 Decimals, Basgit | Plot: 999, Area: 0.015 Acre, Homestead | **PENDING LIVE AUDIT** | Small fractional residential holding. |
| **BHR-GT-25** | BHAGALPUR | COLGONG | ANANDPUR | 500 | 1500 | Brajmohan Singh, 12.500 Acre, Dhanhar-1 | Plot: 1500, Area: 12.500 Acre, Large Estate | **PENDING LIVE AUDIT** | Large multi-acre continuous holding. |
| **BHR-GT-26** | DARBHANGA | HAYAGHAT | SIRNIA | 520 | 1600 | Sunil Kumar, 0.000 Acre (Homestead nil area recorded) | Plot: 1600, Area: 0.000 Acre, Nil area | **PENDING LIVE AUDIT** | Zero area edge case handling. |
| **BHR-GT-27** | PATNA | BARH | MALIKPUR | 78 | 245 | Shyam Sundar (Hindi numerals: ७८, २४५, ३५ डिसमिल) | Plot: 245, Area: 0.350 Acre, 1 Owner | **PENDING LIVE AUDIT** | Devanagari digit extraction verification. |
| **BHR-GT-28** | GAYA | TEKARI | MAU | 550 | 720 | Ajay Kumar Singh, 0.150 Acre, Chauhaddi North/South/East/West | Plot: 720, Area: 0.150 Acre, 4 Boundaries in raw_fields | **PENDING LIVE AUDIT** | Four-side boundary physical verification. |
| **BHR-GT-29** | MUZAFFARPUR | PAROO | DEORIA | 580 | 830 | Vijay Prasad, 0.400 Acre, Mutation Case 12/2022-2023 | Plot: 830, Area: 0.400 Acre, Mutation Ref parsed | **PENDING LIVE AUDIT** | Mutation history tracking audit. |
| **BHR-GT-30** | BHAGALPUR | BIHPUR | MARWA | 600 | 950 | Kishan Lal (Guardian not recorded), 0.200 Acre | Plot: 950, Area: 0.200 Acre, 1 Owner | **PENDING LIVE AUDIT** | Missing optional guardian field handling. |

---

## 3. Protocol for Completing Validation Audit

1. **Step 1**: Offline fixture verification against golden snapshots (Completed — 30/30 passed).
2. **Step 2**: Supervised live session manual sample comparison with authorized operator credentials.
3. **Step 3**: Record-by-record verification of `Match Status` into `VERIFIED_MATCH` or `MISMATCH_LOGGED`.
