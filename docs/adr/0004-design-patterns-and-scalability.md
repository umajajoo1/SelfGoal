# ADR-0004: Design patterns & scalability approach

## Status
Accepted

## Date
2026-09-19

## Context
A solo-built MVP on a tight budget needs to stay maintainable and provider-agnostic (AI vendors may change, diagnostic logic will evolve) without spending scarce time solving scale problems the pilot doesn't have yet.

## Decision
- **Repository pattern** — `skillRepository`, `diagnosticRepository`, `contentRepository`, `progressRepository` abstract Supabase data access away from business logic.
- **Adapter pattern** — `IContentGenerator` and `ITextToSpeech` interfaces wrap Gemini and Google Cloud TTS respectively, so either provider can be swapped without touching calling code.
- **Decorator pattern** — a caching layer wraps the TTS adapter, checking the `tts_cache` table (keyed by a hash of text + voice + language) before calling the real TTS API, conserving the free-tier quota.
- **Strategy pattern** — the diagnostic engine's "which question to ask next" logic is isolated as a swappable strategy, starting rule-based with room to become ML-based later without changing the calling code.
- **Event-driven fan-out** — an in-process event bus: completing an activity emits one event consumed independently by mastery-update, parent-dashboard-refresh, and badge/streak-evaluation handlers.
- **Concurrency approach**: the workload is I/O-bound, not CPU-bound. "Parallelism" here means pre-generating/reviewing content offline in batch rather than live per-request generation, caching TTS output, using scheduled jobs (Vercel Cron) for non-interactive work (weekly reports, badge evaluation), and relying on serverless per-request isolation for concurrent users.
- **Explicitly deferred to post-MVP**: Redis caching, dedicated session servers for live voice AI, message queues — none of these are justified by pilot-scale traffic.

## Consequences
- Some upfront abstraction cost (writing an interface before there's a second implementation) in exchange for cheap provider swaps and business logic that's unit-testable without hitting real AI APIs.
- Deliberately does not solve scaling problems (high concurrency, live STT, queueing) the product doesn't have at pilot stage — revisit this ADR if/when Phase 2 adds live conversational AI.

## Alternatives Considered
- **Direct SDK calls to Gemini/TTS from route handlers** — rejected: hard to unit test, hard to swap providers, couples business logic to a specific vendor's API shape.
- **Message queue from day one** — rejected: premature for pilot-scale traffic; adds an operational dependency with no current justification.
