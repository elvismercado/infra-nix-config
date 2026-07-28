Perform a comprehensive audit of this infra-nix-config repo. Look for issues in 5 categories:

P1 — Security & Correctness: Things that could cause data loss, security holes, or wrong behavior.
P2 — Robustness & Reliability: Failure modes, missing validation, silent errors, race conditions.
P3 — Architecture & Convention: Inconsistencies with the repo's documented module conventions, missing comment headers, inconsistent grouping.
P4 — Module Quality: Duplication, modules in the wrong location, host-level inconsistencies, dead code.
P5 — Script & Documentation Polish: Drift between scripts and their docs, inconsistent error patterns, missing user-facing documentation.
For each finding, write a TODO.md entry in the format:

- [ ] **<Short title>** — <One-sentence problem statement with concrete file/line reference and suggested fix.>

Group by priority. Skip anything already covered by Round 1 (collapsed in <details>). Aim for ~3 items per priority bucket — but quality over quantity: returning zero findings is acceptable when the repo is genuinely clean.

If using a subagent to gather findings, treat its output as a draft: independently verify each finding against the actual file before adding to TODO. Reject phantom findings (claims about files/lines that don't exist or don't match), and consolidate items that are facets of one underlying pattern into a single entry.

When delegating to a subagent, prime it with the list of already-resolved themes from prior rounds (skim TODO.md's checked-off `## Round N` sections). This prevents the subagent from re-surfacing solved patterns and tells it that returning zero findings is acceptable.

## Output location

Append findings to `TODO.md` under a new `## Round N` heading (N = next sequential round number; check the file). Group entries by priority sub-headings (`### P1 — Security & Correctness`, etc.). Use the standard `- [ ] **Title** — description.` checkbox format. After implementation, items are checked off in place — keep the round section as the historical log.
