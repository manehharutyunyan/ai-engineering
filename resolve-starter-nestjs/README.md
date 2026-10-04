# Resolve — v0 "Core Tickets"

Course project for **The AI-Native Engineering Playbook** (ACA).
This is the official reference implementation of v0 — **NestJS +
PostgreSQL (TypeORM) + Docker** — matching PROJECT_BRIEF.md exactly.
If your stack is C#, Python, Go, Java, etc.: port this behavior to your
stack; the brief is the contract, this repo is a working example of it.

## Run (Docker — recommended)

```bash
docker compose up -d --build     # Postgres 16 + the app
curl localhost:3000/stats
```

Port 3000 busy? `APP_PORT=3300 docker compose up -d --build`.
Config is env-driven with sane defaults — `cp .env.example .env` to
override ports or database credentials (never commit `.env`).
Data lives in the `pgdata` volume — it survives restarts and rebuilds.
Reset everything: `docker compose down -v`.

## Run (local dev)

```bash
docker compose up -d db          # just the database
npm install
npm start                        # ts-node, listens on :3000 (PORT to change)
```

`npm start` connects using `DATABASE_URL` (default
`postgres://resolve:resolve@localhost:5432/resolve`). For a compiled build:
`npm run build && npm run start:prod`.

## Test

```bash
npm test                         # 14 tests, no database needed
npx jest -t 'status machine'     # only tests matching a name
```

Tests run against **in-memory SQLite**; runtime uses PostgreSQL. The
entities stick to dialect-neutral column types (dates as ISO strings) so
both behave identically.

## Endpoints (v0)

Mutating requests take an optional `X-Actor` header (default `api`),
which is recorded in the audit log.

- `POST /tickets` — `{ subject, description, customerEmail, priority }`
  (priority: `low | normal | high | urgent`; new tickets start in `new`)
- `GET /tickets?status=&priority=` — list (filterable)
- `GET /tickets/:id` — one ticket, including comments
- `POST /tickets/:id/status` — `{ "to": "open" | ... }` (whitelisted
  transitions; illegal moves → 400 listing allowed next states)
- `POST /tickets/:id/comments` — `{ author, body, internal }`
  (`internal: true` = agent-only note; never expose to customers)
- `GET /audit?ticketId=` — every mutation, with actor (from `X-Actor`
  header); optionally filtered to one ticket
- `GET /stats` — `{ total, byStatus, byPriority, avgResolutionMinutes }`
  (`avgResolutionMinutes` is measured from creation to entering `resolved`,
  `null` if nothing has been resolved yet)

Errors: invalid input → `400` naming the offending field (e.g.
`customerEmail must be a valid email address`); unknown ticket → `404`.
IDs look like `tkt_xxxxxxxx` (tickets) and `cmt_xxxxxxxx` (comments).

### Example

```bash
curl -s localhost:3000/tickets -H 'Content-Type: application/json' \
  -H 'X-Actor: alice' \
  -d '{"subject":"Login broken","description":"500 on submit",
       "customerEmail":"bob@example.com","priority":"high"}'

curl -s localhost:3000/tickets/<id>/status -H 'Content-Type: application/json' \
  -d '{"to":"open"}'
```

## Status machine

```
new → open → in_progress → resolved → closed
                ↑    ↓
           waiting_customer
```

`closed` is terminal. The transition table lives in `ALLOWED_TRANSITIONS`
(`src/tickets/tickets.service.ts`) — the single source of truth.

## Project layout

```
src/
  main.ts, app.module.ts   bootstrap + module wiring
  tickets/                 controller, service, repository, entities, spec
  audit/                   @Global AuditModule: service, controller, entity
  stats/                   GET /stats (reads via TicketsRepository)
  common/ids.ts            newId(prefix)
```

## Conventions in this codebase

- Services never touch the TypeORM DataSource directly — data access goes
  through the module's repository (`TicketsRepository`, `AuditService`).
- Every mutation writes an audit entry: `AuditService.record(actor,
  action, ticketId, details)`; action names are `entity.verb`
  (`ticket.created`, `ticket.status_changed`, `ticket.commented`).
- All input validation lives in `TicketsService` (no DTOs or
  `ValidationPipe`); errors are `BadRequestException` with the offending
  field named. Controllers stay thin.
- Entities use dialect-neutral column types (ISO-string dates,
  `simple-json`, explicit `type` on every column) so the same code runs on
  SQLite in tests and Postgres at runtime.
- Tests use the real service + repository over in-memory SQLite — no
  mocks of our own code.
- `synchronize: true` is a v0 convenience — migrations replace it in a
  later class.

## Deploying

`../terraform/` provisions an EC2 host with Docker + compose installed —
see [its README](../terraform/README.md).

## What comes next (don't build ahead)

Class 3: context kit + tags/canned responses · Class 4: the SLA engine
(spec-driven) · Class 5: review gates + the triage agent · Class 6: SLA
watchdog + self-healing CI · Class 7: chatbot (RAG), MCP, security
hardening · Class 8: capstone.
