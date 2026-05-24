# IDEAS — kiro-calamares-config

## Pending

## Claude's Ideashop

<!-- Session ideas appended here -->

**Idea [git]: CHANGELOG drift gate in up.sh**
Add a non-fatal check to `up.sh` (just before the commit step) that compares `git log --since="<date of newest CHANGELOG.md heading>"` against the staged changes: if there are commits or staged files since the last logged date and CHANGELOG.md isn't among the staged files, print a yellow `log_warn` ("N commits since last CHANGELOG entry — changelog may be stale"). Cheap, advisory only (never blocks the push), and would have caught today's situation where 2026-05-22 had five unlogged fixes under a single partial entry. Parse the date with `grep -m1 '^## 20' CHANGELOG.md`. Reusable across every Kiro repo that follows the dated-CHANGELOG convention — could live in the HQ `up.sh` template.
