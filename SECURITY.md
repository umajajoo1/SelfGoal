# Security Policy

## Scope
This is a pre-1.0, solo-built MVP. Only the version currently deployed on `main` is supported.

## Reporting a Vulnerability
Do not open a public GitHub issue for a suspected vulnerability. Report it privately to the project owner with steps to reproduce and the potential impact. Expect an initial response before a fix timeline is set.

## Design-Level Controls
This product processes a minor's personal data and falls under India's DPDP Act 2023. The full authorization, consent, and data-protection design is recorded in [ADR-0003](docs/adr/0003-security-and-child-data-compliance.md), and enforced directly in [supabase/migrations/0001_init.sql](supabase/migrations/0001_init.sql) (Row-Level Security policies) — not restated here.

## Dependency Security
`npm audit` / Dependabot run in CI on every pull request; high-severity findings block merge before release.
