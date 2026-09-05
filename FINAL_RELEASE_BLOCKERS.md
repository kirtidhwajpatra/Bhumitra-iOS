# BHUMITRA iOS — FINAL RELEASE BLOCKERS & READINESS MATRIX

**Audit Date:** 2026-08-31  
**App Bundle ID:** `com.kirtidhwaj.Bhumitra`  
**Current Safety Checkpoint:** `v2.0.0-analytics-stable` (Commit `dec0d1b`)  

---

## 1. Prioritized Blocker & Task Matrix

### P0 — MUST FIX BEFORE APP STORE PUBLIC SUBMISSION
| Item ID | Category | Description | Current Status | Remediation Plan |
|:---:|---|---|---|---|
| **P0-1** | **Security / ATS** | HTTPS / Custom Domain TLS Migration | **WAITING FOR DOMAIN / TLS** | Complete DNS propagation for `api.bhumitra.app`, provision TLS certificate, and set `NSAllowsArbitraryLoads = false` in `CustomInfo.plist`. (Intentionally postponed). |

---

### P1 — SHOULD FIX BEFORE APP STORE SUBMISSION
| Item ID | Category | Description | Current Status | Remediation Plan |
|:---:|---|---|---|---|
| **P1-1** | **Monetization** | Offline Consumable Pending Sync Queue | **IMPLEMENTED LOCAL FALLBACK** | Add persistent pending JWS queue in Keychain to re-dispatch unconfirmed consumable transactions upon reconnect before calling `transaction.finish()`. |

---

### P2 — POST-LAUNCH POLISH & ENHANCEMENTS
| Item ID | Category | Description | Current Status | Remediation Plan |
|:---:|---|---|---|---|
| **P2-1** | **Networking** | Dynamic Network Reconnect Observer | **FUNCTIONAL** | Automatically trigger `fetchServerCreditBalance()` when `NWPathMonitor` transitions from offline to online. |
| **P2-2** | **Diagnostics** | Remote Feature Flag Cache Persistence | **FUNCTIONAL** | Cache `/api/v1/app-config` payload in UserDefaults for zero-latency splash configuration. |

---

### MANUAL VERIFICATION REQUIRED BEFORE FINAL APP STORE SUBMISSION
| Item ID | Verification Area | Requirement | Status |
|:---:|---|---|:---:|
| **M-01** | **Physical Device QA** | Execute 25 test cases in `TESTFLIGHT_MANUAL_QA_MATRIX.md` on physical iPhone & iPad hardware. | **PENDING TESTFLIGHT BUILD UPLOAD** |
| **M-02** | **Live Sandbox StoreKit** | Test real consumable (+10 plots) and subscription (Monthly Unlimited) purchases using Apple Sandbox tester accounts. | **PENDING TESTFLIGHT BUILD UPLOAD** |
| **M-03** | **VoiceOver / Accessibility** | Verify VoiceOver spoken hierarchy and button accessibility traits on real iOS hardware. | **PENDING TESTFLIGHT BUILD UPLOAD** |
