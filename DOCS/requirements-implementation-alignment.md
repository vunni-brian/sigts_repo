# SIGTS Requirements Implementation Alignment

This document maps key stated requirements to current implementation status in this codebase and highlights immediate next actions.

## 1) Functional Requirements Coverage

- `User authentication and RBAC` - Implemented in `backend/src/routes/auth.js` and `backend/src/middleware/auth.js`.
- `Geofencing validation` - Implemented in `backend/src/routes/geofence.js` using PostGIS `ST_Contains`.
- `Offline synchronization` - Implemented in `backend/src/routes/sync.js` and `frontend/public/sw.js`.
- `IT manager administration` - Implemented in `backend/src/routes/admin.js` with RBAC guard.
- `Sighting tracking` - Implemented in `backend/src/routes/sightings.js` and sync upload flow.

## 2) Non-Functional Requirements Hardening Applied

Recent updates in this patch set:

- Central requirement config added in `backend/src/config/requirements.js`.
- JWT token TTL standardized to `24h` default (configurable via `JWT_ACCESS_TTL`).
- Bcrypt rounds centralized and configurable (`BCRYPT_ROUNDS`, default 12).
- Production fails fast when `JWT_SECRET` is missing/weak.
- Request body size limit centralized (`API_BODY_LIMIT`, default `10mb`).
- Rate limiting centralized and auth-specific throttle added for login endpoints.
- Debug/test auth endpoints now disabled in production.
- CORS policy now blocks disallowed origins in production.

## 3) Remaining Gaps vs Requirements

- `MFA for IT managers` - Not yet implemented.
- `Refresh token/session rotation` - Not yet implemented.
- `Password reset via email` - Not yet implemented.
- `Continuous GPS tracking, speed/bearing ETA` - Partially present, requires dedicated services/jobs.
- `Multilingual content pipeline` - Partial support; translation workflow and content negotiation not complete.
- `Predictive analytics` - Core route exists, but full model training/report scheduling requires expansion.
- `Battery, sync concurrency, storage quotas` - Need runtime telemetry and policy enforcement.

## 4) Next Engineering Steps (Recommended Order)

1. Implement refresh token + session table, then add logout token revocation persistence.
2. Add password reset + email verification flows and endpoints.
3. Add MFA enrollment/challenge for `it_manager` role.
4. Add geofence middleware enforcement policy by route/user role.
5. Add performance/SLO instrumentation (`p95` response time, AI latency, tile timing).
6. Add backup scheduler and retention enforcement for daily backups.
