# ADR Index

Topic-tagged map of all ADRs. Read this **before any non-trivial task** to
find which decisions are already made.

Newer ADRs carry `Triggers:` and `Topics:` near the top -- grep for them when
in doubt: `grep -l "Triggers:.*tv" docs/decisions/*.md`. Older ADRs predate
that convention and don't have them yet; they pick it up if they're touched.

## How to use

1. Identify the area of the task (TV/Zone, player identity, a specific game, deploys, design system).
2. Look up the topic below to see which ADRs are relevant.
3. Read the relevant ADRs **before** writing code, advising, or making a decision in that area.
4. If the task spans topics, read all relevant ADRs.
5. If no ADR covers the area but the decision is significant, use `/adr` to draft a new one.

## Topics

| Topic | ADRs |
|-------|------|
| **TV / Zone / phone controller** | 001, 005, 010 |
| **Player identity & sessions** | 002 |
| **Trivia** | 003 |
| **Descent** | 004 |
| **TV party games (Spotlight, Treasure Hunt, cards)** | 006 |
| **Public game submission** | 007, 016 |
| **Build / retro workflow** | 008 |
| **Golden Goal & QR join** | 009 |
| **Shared design system** | 011, 015 |
| **TV / closed-screen resilience** | 012 |
| **Store hours & opening times** | 012, 013, 018 |
| **Admin area & auth** | 018 |
| **Deployment & infrastructure** | 019 |
| **Leaderboards & scores** | 014, 015, 017 |
| **Puzzle level generation** | 017 |

## All ADRs (chronological)

| # | Title | Status | Date |
|---|-------|--------|------|
| 001 | TV Zone: Single-Scan Reactive Phone Controller | Accepted | 2026-04 |
| 002 | Player Identity and Persistent Sessions | Accepted | 2026-04 / 2026-06 |
| 003 | Trivia: Leave Game from Waiting Screen | Accepted | 2026-04 |
| 004 | Descent: TV Controller Support | Accepted | 2026-04 |
| 005 | Zone Component Naming and Navigation Bug Fixes | Accepted | 2026-04 |
| 006 | TV Party Game Patterns: Spotlight, Treasure Hunt, Card-Game Architecture | Accepted | 2026-05 |
| 007 | Public Game Submission Flow for Non-Developer Families | Accepted | 2026-05 |
| 008 | Build/Retro Memory Loop | Accepted | 2026-06-07 |
| 009 | Golden Goal Penalty Shootout, and QR-Code Join for Static-File TV Games | Accepted | 2026-06-12 |
| 010 | The Phone Contract and the Shared Arcade Session | Accepted | 2026-06-12 |
| 011 | Shared Design System (ez-az-shell.css) | Accepted | 2026-06-12 |
| 012 | Self-Refreshing Idle TV Screens | Accepted | 2026-07-25 |
| 013 | The Server Is Authoritative for Store Hours | Accepted | 2026-07-26 |
| 014 | Leaderboards Rank Players, Not Attempts | Accepted | 2026-07-26 |
| 015 | The Wrapper Around a Game Is Shared Code, Not a Snippet | Accepted | 2026-07-26 |
| 016 | On-Site Submission Form, Idea-Only Submissions, and a Hard Security Floor | Accepted | 2026-07-31 |
| 017 | Chill Games Need a Score, and a Construction-Based Technique for Guaranteed-Solvable Grid Puzzles | Accepted | 2026-08-02 |
| 018 | DB-Backed Store Hours and Admin Magic-Link Login | Accepted | 2026-10-21 |
| 019 | Kamal Is the Sole Deployment System | Accepted | 2026-10-21 |

## Maintenance

When adding a new ADR:
1. Use the next number in sequence (currently next: **020**)
2. Add `Triggers:` and `Topics:` near the top
3. Add a row to the chronological table above
4. Add the ADR number to relevant topic rows above
5. Cross-reference older ADRs in `## Related` if applicable
