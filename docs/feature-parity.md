# Feature parity matrix

Legend: **App** = native screen in this app · **Web** = opens the ERP in the browser (labelled in the app) · **—** = not available on mobile yet.
"Verified" means run against a real ERP on a device. **Nothing in this table is verified yet**: the app has not been compiled (see [limitations.md](limitations.md)).

## Everyone

| Feature | Mobile | API used | Verified |
|---|---|---|---|
| Version gate, maintenance screen | App | `GET bootstrap` | No |
| Staff sign-in + MFA | App | `POST auth/staff/login` | No |
| Phone OTP sign-in, invitation code | App | `POST auth/otp/request`, `auth/otp/verify`, `auth/claim` | No |
| Workspace chooser / switch (only with more than one) | App | `GET me`, `POST auth/workspace` | No |
| Token renewal, re-authentication after 90 days | App | `POST auth/token/renew` | No |
| Biometric unlock of the stored session | App (device only, no server call) | — | No |
| Signed-in devices, sign out device / everywhere | App | `auth/devices`, `DELETE auth/devices/{id}`, `auth/logout`, `auth/logout-all` | No |
| Notifications inbox, read, read all | App | `notifications*` | No |
| Notification topic settings | App | `GET/PUT notifications/preferences` | No |
| Push notifications (FCM/APNs) | App (needs your Firebase project values, see push.md) | `devices/push`, `DELETE devices/push` | No |
| Help desk: list, create with files, chat, actions | App | `support/categories`, `cases*`, `attachments/{id}` | No |
| Calendar agenda + RSVP | App | `calendar`, `calendar/invitations/{id}/respond` | No |
| Language EN/AR (RTL), theme, motion setting | App | — | No |
| Links `onesource://cases/…`, `trips/…`, `attendance` from outside the app and from push | App | — | No |
| Unsent case text kept as a draft on the phone | App | — | No |

## Staff

| Feature | Mobile | API used | Verified |
|---|---|---|---|
| Module library from server permissions | App | `GET me` (`permissions`, `areas`, `modules`) | No |
| Attendance: today, check in / break / check out, location | App (agent companies) | `attendance/today`, `attendance/punch` | No |
| Attendance month, correction requests | App | `attendance/month`, `attendance/corrections` | No |
| Team board and correction approvals (managers) | App | `attendance/team`, `attendance/approvals`, `attendance/approvals/{id}/approve\|reject` (PR #254) | No |
| "Mark your attendance" reminder | App (home card) | `attendance/today` | No |
| Admin requests to users (e.g. change password) | App shows count, completes on Web | `GET me` → `requests` | No |
| Help desk queues, internal notes, assign | App | `cases?queue=`, `cases/{id}/messages`, `actions/*` | No |
| Renewals queues and status moves | App | `renewals`, `renewals/{ref}/actions/{status}` | No |
| Care calls: record / no answer | App | `care/checkins*` | No |
| Bed board, check in / out a stay | App | `accommodation/board`, `accommodation/stays/{id}/{action}` | No |
| Assign / move a bed | App | `accommodation/subjects` (PR #254), `POST accommodation/stays`, `stays/{id}/move` | No |
| Driver day, milestones, PIN, passengers, photo proof, decline | App | `driver/trips`, `trips/{ref}/*` | No |
| Driver milestones without signal (sent later with original time and place) | App (outbox) | `trips/{ref}/status` with `reported_at` | No |
| Trainer sessions, roster attendance, check-in code as QR | App | `training/staff/sessions*` | No |
| Assessor rubric form with evidence photos | App | `training/staff/assessor-tasks` (rubric added in PR #254), `…/assessments` | No |
| Training nomination approvals | App | `training/staff/approvals` (PR #254), `…/approve` | No |
| CRM, finance, HRM, outside recruitment, packages, agent network, GM, chatbot, events admin | Web | — | — |

## Customers and workers

| Feature | Mobile | API used | Verified |
|---|---|---|---|
| Worker home: documents, bed, trips, training, certificates | App | `my/overview` | No |
| Customer home: placements, contracts, recruitment, pickup | App | `my/overview` | No |
| My learning, catalogue, request, withdraw | App | `training/my`, `training/catalogue`, `training/requests`, `training/enrolments/{id}/withdraw` | No |
| Session check-in by QR scan or typed code | App | `training/sessions/{id}/check-in` | No |
| Course materials (text, files) and quizzes with saved progress | App | `training/courses/{code}/materials`, `materials/{id}/file`, `quizzes/{id}`, `quizzes/{id}/draft` | No |
| Shortlists: candidates with photo/video, match score; choose or book a video interview | App (customer) | `my/shortlists`, `my/shortlists/{id}/choose\|interview` (PR #254) | No |
| Ask the office for candidates | App (customer) | `POST cases` (category recruitment) | No |
| Agreements: read (EN/AR/local) and sign with a drawn signature | App (customer) | `my/agreements`, `my/agreements/{kind}/{ref}`, `…/sign` (PR #254, same rules as the web signing page) | No |
| Invoices, receipts, balance | App (customer) | `my/invoices` (PR #254) | No |
| Pay: send transfer proof to the office | App (customer) | `POST cases` (category payments, linked contract) | No |
| Online card payment inside the app | — | needs a payment provider account (see limitations) | — |
| Salary statements, ask about a salary | App (worker) | `my/salaries` (PR #254), `POST cases` (category salary) | No |
