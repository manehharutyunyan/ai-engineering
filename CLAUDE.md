# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Resolve**, a support-ticket API built as the course project for *The AI-Native Engineering Playbook* (ACA). It has two independent subprojects:

- `resolve-starter-nestjs/`: the v0 "Core Tickets" app (NestJS 11, TypeORM, PostgreSQL 16, Docker). A `PROJECT_BRIEF.md` (not in this folder) is the behavioral contract, and this app is its reference implementation.
- `terraform/`: provisions a single EC2 host (Amazon Linux 2023, with Docker and compose installed by `user-data.sh`) that the app is deployed to.

**Don't build ahead.** Later classes add tags/canned responses, an SLA engine, a triage agent, CI, RAG chatbot/MCP, and a capstone. Implement only what the current task asks for.

## Commands (run from `resolve-starter-nestjs/`)

```bash
docker compose up -d --build      # Postgres + app on :3000 (APP_PORT=3300 to remap)
docker compose up -d db           # DB only, for local dev
npm start                         # ts-node src/main.ts (PORT, DATABASE_URL env)
npm run build                     # tsc -> dist/
npm test                          # jest; no DB needed (in-memory SQLite)
npx jest -t 'status machine'      # run tests matching a describe/it name
npx jest src/tickets/tickets.service.spec.ts
docker compose down -v            # reset, including the pgdata volume
```

There is no lint script and no ESLint/Prettier config.

Terraform (from `terraform/`): `terraform init && terraform plan && terraform apply`; `terraform destroy` to tear down. State is local. `terraform.tfvars` and state are not committed.

## Architecture

The modules are `AuditModule` (`@Global`), `TicketsModule`, and `StatsModule`, wired in `src/app.module.ts`. TypeORM uses `autoLoadEntities` and `synchronize: true`; migrations are planned for a later class.

- **Layering:** controller → service → repository. Controllers are thin, take `X-Actor` (default `'api'`), and pass raw bodies through. **All input validation lives in `TicketsService`.** There are no DTOs or `ValidationPipe`. Invalid input throws `BadRequestException` naming the offending field, and a missing ticket throws `NotFoundException`.
- **Data access:** services never use the DataSource directly; they go through `TicketsRepository` or `AuditService`. `TicketsRepository.save()` stamps `updatedAt` and sorts comments. `StatsController` reads through `TicketsRepository`, which `TicketsModule` exports.
- **Status machine:** `ALLOWED_TRANSITIONS` in `tickets.service.ts` is the single source of truth: `new→open→in_progress→{waiting_customer,resolved}`, `waiting_customer→in_progress`, `resolved→closed`, and `closed` is terminal. An illegal move returns a 400 that lists the allowed next states. Entering `resolved` sets `resolvedAt`, which drives `avgResolutionMinutes` in `/stats`.
- **Audit:** every mutation calls `AuditService.record(actor, action, ticketId, details)`, with action names in `entity.verb` form (`ticket.created`, `ticket.status_changed`, `ticket.commented`).
- **Comments** are saved through cascade on the `Ticket` aggregate: push onto `ticket.comments` and save the ticket. Comments are eager-loaded. `internal: true` marks an agent-only note that must never be exposed to customers.
- **IDs** come from `newId(prefix)` in `src/common/ids.ts` (`tkt_xxxxxxxx`, `cmt_xxxxxxxx`). Comments and audit entries also have an auto-increment `seq` that is used for ordering.

## Dialect-neutral entities

Tests run on in-memory **better-sqlite3**, while runtime uses **Postgres**. Keep column types portable: store dates as ISO-8601 `varchar` strings (not `timestamp`), store JSON as `simple-json`, and give every column an explicit `type`. Anything Postgres-specific will break the tests.

## Testing conventions

Specs build a Nest `TestingModule` with the **real** service, repository, and `AuditService` over SQLite (`dropSchema: true`). Don't mock this project's own code. Register every entity a test touches in both `forRoot({ entities })` and `forFeature`. The `better-sqlite3` package is test-only, and the Dockerfile installs with `--ignore-scripts`, so it never builds in the image.
