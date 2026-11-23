# ERP API used by the app

Base: `{API_BASE_URL}/api/mobile/v1`. The full contract is `docs/connect/openapi.yaml` in the ERP repository (Development-Hubs/chatbot); the Flutter hand-off notes are in `docs/connect/04-flutter-handoff.md`.

## Conventions the client implements

* Envelope `{ok, data, meta}`; errors `{ok:false, error:{code, message, fields}}`. Screens switch on `error.code` and show `error.message`.
* Headers: `Authorization: Bearer oc_…`, `Accept-Language: en|ar`, `Idempotency-Key` on every change.
* Pages: `?page=&per_page=`, `meta.page` / `meta.last_page`.
* Session-ending codes: `unauthenticated`, `token_expired`, `token_revoked`, `reauthentication_required`, `workspace_revoked`, `account_blocked`, `company_unavailable`.

## Added for this app (chatbot PR #253)

### `GET me` (staff)

Adds `user_id`, `owner`, `permissions[]`, `data_scope` (`own|team|all`), `modules[]` (enabled ERP modules), `attendance` (bool), `requests` (pending admin requests), `web_url`, and `company.kind|timezone|currency`.

### Attendance (staff of agent companies; partner companies answer `404 module_disabled`)

| Call | Body / query | Answer |
|---|---|---|
| `GET attendance/today` | — | `data`: `state` (`off|in|break|out`), `actions[]`, `first_in`, `last_out`, `worked_seconds`, `break_seconds`, `break_allowance_seconds`, `target_seconds`, `shift_start/end`, `late_minutes`, `timeline[]`…; `meta`: `timezone`, `needs_location`, `where`, `radius`, `break_minutes`, `max_breaks` |
| `POST attendance/punch` | `type` (`in|break_start|break_end|out`), `lat?`, `lng?`, `accuracy?`, `note?` + `Idempotency-Key` | the updated day; `422 invalid_transition` when not allowed now |
| `GET attendance/month` | `?month=YYYY-MM` | `days[]`, `totals` |
| `GET attendance/corrections` | — | my requests; `meta.kinds` |
| `POST attendance/corrections` | `date`, `kind`, `check_in?`, `check_out?`, `break_minutes?`, `reason` + `Idempotency-Key` | `201 {id, status}` |

The same `WebAttendance` service and company rules (location radius, breaks, shift) are used as on the web dashboard.
