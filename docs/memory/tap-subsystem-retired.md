---
name: tap-subsystem-retired
description: The RPC/HL7→S3 traffic-tap subsystem is fully removed from v-stdlib; don't go looking for VSLTAP*/VSLS3, and beware the dual tracked/untracked quarantine trap.
metadata:
  type: project
---

The prior **RPC/HL7 → S3 traffic-tap subsystem is fully retired and REMOVED from
the tree** (commit `29b07a0`, 2026-06-29): `VSLTAP` / `VSLRPCTAP` / `VSLRPCWRAP`
/ `VSLS3` / `VSLHL7TAP` / `VSLTAPFC` / `VSLTAPHL` + their tests/examples/docs +
`s3-testbed.sh` (37 files, 5,712 LOC). It was built against the now-retired
`CALLP^XWBBRK` `{XWB}` callback seam; the greenfield replacement is **`v-rpc-tap`**
against the live `CALLP^XWBPRS` `[XWB]` path — design in the `docs` repo
`proposals/v-rpc-tap-scalable.md`. Recover any old content from git history; do
**not** reintroduce these routines. Lingering `quarantine` mentions in proposals/
memory are accurate *history*, not live pointers — nothing to chase.

**The trap that wasted a cycle (the durable lesson):** quarantine existed in **two
desynced states at once** —
1. **tracked** at repo-root `quarantine/` (37 files, what CI actually checked out),
   already **deleted from disk** but the deletion never committed (a cadence
   automation had `rm`'d it mid-session); and
2. an **untracked** on-disk copy under `docs/quarantine/` (never in git, never in
   CI — local clutter only).

Consequences to remember: **a local working-tree folder is NOT proof of what CI
sees — check `git ls-files` / tracked-vs-untracked first.** I wrongly diagnosed
"CI docs-validate is red on `docs/quarantine`" — CI never saw it (untracked, and
even the tracked copy sat at root, outside the `docs/`-only link-check). The
`link-check.py` `quarantine` exclude (`doc-framework` `eb48103`) is still fine as a
frozen-area rule, but its commit-message rationale is inaccurate. Also: `rm -rf`
and `git clean` are **sandbox-denied here** — the user deleted the untracked
folder by hand.

Process note tied to this: run the **full** gate (`make check-fast` / `gates`),
not just `link-check`+`check-docs`, before committing — a `docker exec` mention in
`tests/README.md` had been silently failing `check-engine-access` (reword prose to
avoid the literal token, or use a `stack-exempt:` marker). See
[[vsl-wrapping-baseline-audit]].
