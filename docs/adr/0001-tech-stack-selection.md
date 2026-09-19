# ADR-0001: Tech stack selection

## Status
Accepted

## Date
2026-09-19

## Context
Phase 1 must ship as an MVP under a ₹50,000 budget, built solo (no hired developers), for an English-fluency app targeting CBSE class 2–5 students. This rules out anything requiring dedicated ops staff, paid infra from day one, or a multi-repo/multi-language split that slows a single developer down.

## Decision
- **Next.js (App Router, TypeScript, Tailwind CSS)** — one codebase for frontend + API routes (serverless functions).
- **Vercel free tier** for hosting; deploys straight from the Next.js repo with zero extra config.
- **Supabase** (managed Postgres + Auth + Storage) — the skill graph / diagnostics / mastery data is inherently relational, and Auth + Storage come bundled instead of being separate services to wire up.
- **Google Gemini API** for content generation — free tier available during development.
- **Google Cloud Text-to-Speech** — Standard/WaveNet voices include a recurring free monthly quota, with en-IN voices suited to Indian-accented narration.
- **Razorpay** for payments — deferred to Phase 2, not part of the MVP build.

## Consequences
- One language (TypeScript) across the entire stack — no context-switching for a solo developer.
- Serverless functions on Vercel scale horizontally with zero capacity planning; Supabase Postgres scales vertically + read replicas if needed later.
- Free tiers impose quota ceilings (Gemini rate limits, TTS character caps) that must be actively monitored (see [ADR-0004](0004-design-patterns-and-scalability.md)).
- Vendor lock-in to Supabase/Vercel/Google is accepted in exchange for near-zero infrastructure setup time.

## Alternatives Considered
- **Separate Node/Express backend + React SPA** — rejected: doubles deployment/ops surface for no MVP-stage benefit.
- **Firebase (Firestore)** — rejected: the skill/mastery/diagnostic data model is relational (foreign keys, joins for spaced repetition queries); a document store fits this domain poorly.
- **No-code/WordPress plugin stack** — rejected: the adaptive diagnostic engine needs custom logic no no-code platform supports cleanly.
- **Java (Spring Boot) or Python (Django/FastAPI) backend + a separate React frontend** — rejected for this project's constraints specifically: neither renders a UI, so a second language would sit *alongside* JS/TS anyway (not instead of it), doubling the ecosystems a solo developer maintains and duplicating data models across a language boundary. Vercel's free tier has no first-class Java support and only limited Python function support, pushing hosting to a paid or higher-ops alternative. JVM cold starts are also a poor fit for serverless functions. Python would be the stronger choice if this project trained/served its own ML models, but it calls Gemini/Google TTS as external APIs, so that advantage doesn't apply here. Revisit if the team grows or heavy custom compute/ML becomes a real requirement.
