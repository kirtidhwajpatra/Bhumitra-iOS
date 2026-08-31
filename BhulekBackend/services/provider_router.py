"""
Provider Router Layer
Dispatches RoR lookup requests to state-specific providers (Odisha or Bihar)
while ensuring complete isolation, fail-closed feature gating, and zero cross-provider fallback.
"""

import logging
from typing import Optional, Dict, Any

from core.config import settings
from models.ror_response import RoRResponse, RoRErrorCode
from services.ror_service import RoRService, RoRServiceException
from services.bihar_ror_service import BiharRoRService, BiharRoRServiceException

logger = logging.getLogger("bhumitra.provider_router")


class ProviderRouter:
    """
    Thin, stateless router dispatching land-record requests to isolated state providers.
    """

    def __init__(
        self,
        odisha_service: Optional[RoRService] = None,
        bihar_service: Optional[BiharRoRService] = None,
    ):
        self.odisha_service = odisha_service or RoRService()
        self.bihar_service = bihar_service or BiharRoRService()

    async def get_ror(
        self,
        district: str,
        tahasil: str,
        village: str,
        plot: str,
        state: Optional[str] = "ODISHA",
        khata: Optional[str] = None,
        b_id: Optional[str] = None,
        v_id: Optional[str] = None,
        request_id: str = "req-unknown",
        raw_html: Optional[str] = None,
        raw_payload: Optional[Dict[str, Any]] = None,
    ) -> RoRResponse:
        """
        Dispatches request strictly based on normalized state identifier.
        """
        norm_state = (state or "ODISHA").strip().upper()
        req_tag = request_id[:8] if request_id else "unknown"

        # 1. Bihar Provider Branch
        if norm_state == "BIHAR":
            logger.info(f"[{req_tag}] Routing request to Bihar provider: district={district}, anchal={tahasil}, village={village}, plot={plot}")

            # Fail-closed feature flag check
            if not settings.BIHAR_PROVIDER_ENABLED:
                logger.warning(f"[{req_tag}] Bihar provider is disabled by feature flag.")
                raise RoRServiceException(
                    code=RoRErrorCode.BHULEKH_TEMPORARILY_UNAVAILABLE,
                    message="Bihar land records provider is currently disabled by administrative feature flag.",
                    retryable=False,
                    details="provider=bihar, enabled=false",
                )

            try:
                result = await self.bihar_service.get_ror(
                    district=district,
                    anchal=tahasil,
                    village=village,
                    plot=plot,
                    khata=khata,
                    request_id=request_id,
                    raw_html=raw_html,
                    raw_payload=raw_payload,
                )
                return result
            except BiharRoRServiceException as be:
                # Convert to RoRServiceException for standard router error mapping
                raise RoRServiceException(
                    code=be.code,
                    message=be.message,
                    retryable=be.retryable,
                    details=be.details or "provider=bihar",
                )
            except Exception as e:
                logger.error(f"[{req_tag}] Unexpected error in Bihar provider: {str(e)}")
                raise RoRServiceException(
                    code=RoRErrorCode.SERVER_ERROR,
                    message=f"Bihar provider error: {str(e)}",
                    retryable=False,
                    details="provider=bihar",
                )

        # 2. Odisha Provider Branch (Default / Baseline)
        elif norm_state == "ODISHA":
            logger.info(f"[{req_tag}] Routing request to Odisha provider: district={district}, tahasil={tahasil}, village={village}, plot={plot}")
            return await self.odisha_service.get_ror(
                district=district,
                tahasil=tahasil,
                village=village,
                plot=plot,
                b_id=b_id,
                v_id=v_id,
                request_id=request_id,
            )

        # 3. Unsupported State
        else:
            logger.warning(f"[{req_tag}] Unknown or unsupported state requested: {norm_state}")
            raise RoRServiceException(
                code=RoRErrorCode.AMBIGUOUS_LOCATION,
                message=f"Unsupported state '{norm_state}'. Valid supported states: ODISHA, BIHAR.",
                retryable=False,
                details=f"unsupported_state={norm_state}",
            )


# Global provider router singleton
provider_router = ProviderRouter()
