"""
Bhumitra - Odisha IGR Benchmark Valuation Models
Normalized data structures for government land valuation and benchmark rates.
"""
from typing import Optional, List
from pydantic import BaseModel, Field


class IGRValuationCandidate(BaseModel):
    candidate_token: str = Field(..., description="Secure server verification token")
    registration_office_id: int = Field(..., description="IGR Sub-Registrar / Registration office ID")
    registration_office_name: str = Field(..., description="Official Sub-Registrar / Registration office name")
    village_id: int = Field(..., description="IGR village ID")
    village_name: str = Field(..., description="Official Village - Thana designation")
    thana_number: Optional[str] = Field(None, description="Extracted Thana number if available")
    confidence: str = Field("medium", description="'high', 'medium', or 'low'")
    score: float = Field(0.0, description="Deterministic resolution score")
    match_reasons: List[str] = Field(default_factory=list, description="Explanations for why candidate matched")


class IGRUnitRates(BaseModel):
    per_acre: float = Field(..., description="Government benchmark rate per Acre in INR")
    per_hectare: float = Field(..., description="Government benchmark rate per Hectare in INR")
    per_decimal_100: float = Field(..., description="Government benchmark rate per Decimal (100D = 1 Acre) in INR")
    per_decimal_1000: float = Field(..., description="Government benchmark rate per Decimal (1000D = 1 Acre) in INR")
    per_square_meter: float = Field(..., description="Government benchmark rate per Square Meter in INR")
    per_square_foot: float = Field(..., description="Government benchmark rate per Square Foot in INR")


class IGRBenchmarkCalculation(BaseModel):
    indicative_benchmark_amount: Optional[float] = Field(None, description="Calculated total amount based on actual parcel area and benchmark rate")
    calculation_available: bool = Field(False, description="True if parcel area and rate permitted valid arithmetic calculation")
    formula: Optional[str] = Field(None, description="Human-readable formula string, e.g. '2.40 Decimal × ₹5,029.07/Decimal = ₹12,069.77'")
    rate_per_decimal: Optional[float] = Field(None, description="Rate per decimal used in calculation")


class IGRBenchmarkValuationResponse(BaseModel):
    status: str = Field(..., description="'AVAILABLE', 'NOT_FOUND', 'AMBIGUOUS', 'MAPPING_REQUIRES_USER_SELECTION', 'MAPPING_UNRESOLVED', or 'UNAVAILABLE'")
    reason: Optional[str] = Field(None, description="Structured failure reason: 'NO_BENCHMARK_RECORD', 'MULTIPLE_IGR_VILLAGES', 'REQUIRES_USER_SELECTION', 'PLOT_NOT_FOUND_IN_JURISDICTION', 'INVALID_CANDIDATE_SELECTION', 'VILLAGE_MAPPING_UNRESOLVED', 'REGISTRATION_OFFICE_UNRESOLVED', 'IGR_SERVICE_TIMEOUT', 'IGR_SERVICE_ERROR', 'MALFORMED_UPSTREAM_RESPONSE'")
    source: str = Field("Odisha Inspector General of Registration (IGR)", description="Data provenance")
    source_url: str = Field("https://igrodisha.gov.in/ViewFeeValue.aspx", description="Official source URL")
    retrieved_at: str = Field(..., description="ISO 8601 UTC timestamp of retrieval")

    district: str = Field(..., description="Standardized district name")
    registration_office: Optional[str] = Field(None, description="Official Sub-Registrar / Registration Office name")
    village_thana: Optional[str] = Field(None, description="Official Village - Thana designation")
    kisam: Optional[str] = Field(None, description="Land classification category in IGR")
    plot_number: str = Field(..., description="Cadastral plot number")

    query_area: float = Field(1.0, description="Area value used to query standard benchmark rates")
    query_unit: str = Field("Decimal (100D=1Acre)", description="Unit used in rate query")

    actual_parcel_area: Optional[float] = Field(None, description="True cadastral parcel area")
    actual_parcel_area_unit: Optional[str] = Field(None, description="Unit of actual parcel area (e.g. 'Decimal', 'Acre')")

    area_wise_benchmark_value: Optional[float] = Field(None, description="Reported benchmark value for the queried area")
    unit_rates: Optional[IGRUnitRates] = Field(None, description="Normalized benchmark rates per standard area unit")

    highest_transaction_value: Optional[float] = Field(None, description="Highest recorded transaction value in area if available")
    transaction_date: Optional[str] = Field(None, description="Date of highest transaction if recorded")

    stamp_duty_estimate: Optional[float] = Field(None, description="Estimated stamp duty based on queried unit")
    registration_fee_estimate: Optional[float] = Field(None, description="Estimated registration fee based on queried unit")

    calculation: IGRBenchmarkCalculation = Field(default_factory=IGRBenchmarkCalculation)
    cached: bool = Field(False, description="True if served from server-side cache")
    message: Optional[str] = Field(None, description="Informational or error message")

    # User-Assisted Fallback additions
    candidates: Optional[List[IGRValuationCandidate]] = Field(None, description="List of potential candidate jurisdictions for user selection")
    user_assistance_used: bool = Field(False, description="True if valuation was resolved through user-assisted candidate selection")
    selection_mode: Optional[str] = Field(None, description="'AUTOMATIC' or 'USER_ASSISTED'")


class IGRDeedInfo(BaseModel):
    id: int = Field(..., description="Official IGR SubDeed ID")
    name: str = Field(..., description="Official SubDeed Name")
    description: Optional[str] = Field(None, description="Human readable description")
    women_concession_eligible: bool = Field(False, description="True if women buyer concession applies to this deed")


# Official sub-deeds directly verified from Odisha IGR (StampDutyCalc.aspx/ListSubDeed)
IGR_OFFICIAL_DEEDS = [
    IGRDeedInfo(id=1, name="SALE IMMOVABLE", description="Standard conveyance of immovable property", women_concession_eligible=True),
    IGRDeedInfo(id=36, name="GIFT IMMOVABLE", description="Gift of immovable property", women_concession_eligible=True),
    IGRDeedInfo(id=34, name="EXCHANGE OF PROPERTY ", description="Exchange of immovable property", women_concession_eligible=False),
    IGRDeedInfo(id=49, name="PARTITION", description="Partition of property", women_concession_eligible=False),
    IGRDeedInfo(id=56, name="POA WITH POSSESSION", description="Power of Attorney with possession", women_concession_eligible=False),
    IGRDeedInfo(id=77, name="SETTLEMENT", description="Settlement deed", women_concession_eligible=False),
    IGRDeedInfo(id=190, name="SALE IMMOVABLE WITH  AGREEMENT", description="Sale of immovable property with agreement", women_concession_eligible=False),
]

# Official unit parameters for GetDoMRVal / GetMRVal
IGR_UNIT_CONFIGS = {
    "Decimal": {"unit_code": "100", "unit_text": "Decimal (100D=1Acre),", "factor_to_acre": 0.01},
    "Decimal (100D=1Acre)": {"unit_code": "100", "unit_text": "Decimal (100D=1Acre),", "factor_to_acre": 0.01},
    "Decimal (1000D=1Acre)": {"unit_code": "1000", "unit_text": "Decimal (1000D=1Acre),", "factor_to_acre": 0.001},
    "Acre": {"unit_code": "1", "unit_text": "Acre,", "factor_to_acre": 1.0},
    "Hectare": {"unit_code": "0.4046685642", "unit_text": "Hectare,", "factor_to_acre": 2.47105},
    "Sq Meter": {"unit_code": "4046.856422", "unit_text": "Sq Meter,", "factor_to_acre": 0.000247105},
    "Sq Feet": {"unit_code": "43560", "unit_text": "Sq Feet,", "factor_to_acre": 1.0 / 43560.0},
}


class IGRRegistrationEstimateRequest(BaseModel):
    district: str = Field(..., description="District name (e.g. 'KENDUJHAR')")
    tahasil: Optional[str] = Field(None, description="Tahasil name (e.g. 'KEONJHAR SADAR')")
    village: Optional[str] = Field(None, description="Village name (e.g. 'G KERI 271')")
    plot: str = Field(..., description="Cadastral plot number (e.g. '1009')")
    kism: Optional[str] = Field(None, description="Land classification category if known")
    area: float = Field(1.0, gt=0, description="Area for calculation")
    unit: str = Field("Decimal", description="Area unit: 'Decimal', 'Acre', 'Hectare', 'Sq Meter', 'Sq Feet'")
    deed_type: str = Field("SALE IMMOVABLE", description="Deed type name")
    deed_id: Optional[int] = Field(None, description="Official IGR Deed ID (1 for SALE IMMOVABLE)")
    buyer_category: str = Field("STANDARD", description="'STANDARD' or 'WOMEN_BUYER'")
    
    # Optional jurisdiction overrides / user-assisted tokens
    registration_office: Optional[str] = Field(None, description="Registration office name if known")
    village_thana: Optional[str] = Field(None, description="Village thana name if known")
    selected_regoff_id: Optional[int] = Field(None, description="User-selected Sub-Registrar / Registration office ID")
    selected_village_id: Optional[int] = Field(None, description="User-selected IGR Village ID")
    candidate_token: Optional[str] = Field(None, description="Server-issued candidate verification token")
    b_id: Optional[str] = Field(None, description="Optional GIS block code")
    v_id: Optional[str] = Field(None, description="Optional GIS village code")
    force_refresh: bool = Field(False, description="Force refresh ignoring cache")


class IGRRegistrationEstimateResponse(BaseModel):
    status: str = Field(..., description="'AVAILABLE', 'NOT_FOUND', 'MAPPING_UNRESOLVED', 'MAPPING_REQUIRES_USER_SELECTION', 'MISSING_DEED_TYPE', 'INVALID_INPUT', or 'UNAVAILABLE'")
    reason: Optional[str] = Field(None, description="Structured failure code")
    source: str = Field("Odisha Inspector General of Registration (IGR)", description="Data provenance")
    source_url: str = Field("https://igrodisha.gov.in/StampDutyCalc.aspx", description="Official source URL")
    calculated_at: str = Field(..., description="ISO 8601 UTC timestamp of calculation")

    district: str = Field(..., description="Standardized district name")
    registration_office: Optional[str] = Field(None, description="Official Sub-Registrar / Registration Office name")
    village_thana: Optional[str] = Field(None, description="Official Village - Thana designation")
    kisam: Optional[str] = Field(None, description="Land classification category in IGR")
    plot_number: str = Field(..., description="Cadastral plot number")

    selected_area: float = Field(..., description="Land area used for this estimate")
    selected_unit: str = Field(..., description="Unit of measurement used for this estimate")

    # Official Unit Rates
    benchmark_rate_per_decimal: Optional[float] = Field(None, description="Official statutory rate per Decimal")
    benchmark_rate_per_acre: Optional[float] = Field(None, description="Official statutory rate per Acre")
    benchmark_rate_per_hectare: Optional[float] = Field(None, description="Official statutory rate per Hectare")
    benchmark_rate_per_sq_meter: Optional[float] = Field(None, description="Official statutory rate per Sq Meter")
    benchmark_rate_per_sq_foot: Optional[float] = Field(None, description="Official statutory rate per Sq Foot")

    # Benchmark Valuation for Area
    benchmark_value_for_area: Optional[float] = Field(None, description="Official benchmark valuation for selected area")

    # Deed Type & Buyer Information
    deed_type: str = Field("SALE IMMOVABLE", description="Deed type used in calculation")
    deed_id: int = Field(1, description="Official IGR SubDeed ID")
    buyer_category: str = Field("STANDARD", description="'STANDARD' or 'WOMEN_BUYER'")

    # Financial charges (statutory exact Decimal calculation)
    stamp_duty: Optional[float] = Field(None, description="Statutory stamp duty amount")
    registration_fee: Optional[float] = Field(None, description="Statutory registration fee amount")
    total_government_charges: Optional[float] = Field(None, description="Total statutory government charges (Stamp Duty + Registration Fee)")

    # Women Buyer Concession Breakdown
    women_buyer_concession_applicable: bool = Field(False, description="True if women buyer concession applies")
    concession_amount: Optional[float] = Field(None, description="Amount saved through concession if applicable")
    total_after_concession: Optional[float] = Field(None, description="Final total charges after deducting concession")

    formula: Optional[str] = Field(None, description="Human readable calculation formula")
    cached: bool = Field(False, description="True if served from server-side cache")
    message: Optional[str] = Field(None, description="Informational or error message")

    # Candidates if user selection is required
    candidates: Optional[List[IGRValuationCandidate]] = Field(None, description="Candidate jurisdictions for user-assisted recovery")
    user_assistance_used: bool = Field(False, description="True if resolved via user selection")
    selection_mode: Optional[str] = Field(None, description="'AUTOMATIC' or 'USER_ASSISTED'")


