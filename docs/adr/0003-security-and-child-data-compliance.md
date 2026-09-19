# ADR-0003: Security & child data compliance

## Status
Accepted

## Date
2026-09-19

## Context
This app processes a minor's personal data (name, date of birth, voice recordings, progress history), which falls under India's **Digital Personal Data Protection (DPDP) Act 2023**. The design must minimize the chance that a single application bug leaks one family's data to another, and must produce evidence of compliance, not just a claim of it.

## Decision
- **Authentication**: parents only hold login credentials (Supabase Auth). Magic-link/OTP is preferred over passwords to remove credential-stuffing risk entirely.
- **Authorization**: Postgres **Row-Level Security is the enforcement boundary**, not app-layer `if` checks — every child-scoped table's policy traces back to `auth.uid()`. A bug in a Next.js API route that forgets a filter still cannot leak another family's rows, because Postgres itself refuses them. Policies are defined alongside the schema in [supabase/migrations/0001_init.sql](../../supabase/migrations/0001_init.sql).
- **Key separation**: the `anon` Supabase key is the only one ever shipped to the browser (safe — every query is still RLS-filtered); the `service_role` key (bypasses RLS) is server-side only, never in client bundles or `NEXT_PUBLIC_*` variables.
- **Consent as an auditable record, not a checkbox**: `consent_records` stores timestamp, IP, and the exact policy version a parent agreed to, per consent type (ToS, child-data-processing, marketing).
- **Audio storage**: speaking recordings and cached TTS audio live in a **private** Storage bucket, served only via short-lived signed URLs — never a permanent public URL for a child's voice recording.
- **Right to erasure**: cascading deletes (`on delete cascade`) are built into the schema itself, so a "delete my child's data" action removes everything in one operation, not a manual multi-table cleanup.
- **Data minimization**: only fields needed to run the product are collected (first name/nickname, DOB for age-banding, grade, progress) — no address, no school name, no unnecessary PII.
- **No behavioral advertising / third-party trackers** on any child-facing screen.

## Consequences
- RLS-first authorization fails **closed** (deny) instead of failing open if application code has a bug — the safer default for data involving minors.
- Adds query complexity (nested `exists`/`in` subqueries for tables one hop from `children`, e.g. `diagnostic_responses` via `session_id`) compared to trusting the app layer.
- A lawyer review of the ToS/Privacy Policy's children's-data clause is a required budget line item (~₹10,000), not an optional one — it is not cut for budget savings.

## Alternatives Considered
- **App-layer-only authorization** — rejected: one missed `where` clause becomes a data breach involving children's data.
- **Public storage bucket with unguessable URLs** — rejected: "security by obscurity" is not an acceptable control for a minor's voice recordings.
