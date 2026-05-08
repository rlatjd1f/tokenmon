# Provider Proposal Contract

**Document status:** Public contribution contract
**Audience:** External contributors and maintainers reviewing provider integrations
**Related docs:** `../../CONTRIBUTING.md`, `../architecture/public-source-overview.md`

---

## 1. Purpose

Tokenmon can accept provider integration proposals, but a new provider is not an
ordinary code-only change. Provider code defines what local usage data Tokenmon
observes, how that data is normalized, and what privacy guarantees the app keeps.

Open an issue with the Provider Proposal template before opening a full
implementation PR. A draft PR can be useful for discussion, but it is not
merge-ready until the contract below is documented and tested.

---

## 2. Non-Negotiable Privacy Rules

- Tokenmon gameplay must not require reading or storing prompt text.
- Tokenmon gameplay must not require reading or storing model response text.
- Tokenmon must not add semantic prompt analysis, keyword matching, or prompt
  indexing as part of a provider integration.
- Fixtures must be synthetic or redacted so they contain only the fields
  Tokenmon needs for usage accounting and diagnostics.

If the provider source cannot support these rules, it is not a fit for the
public P0 provider lane.

---

## 3. Required Proposal Content

A provider proposal must include:

1. **Machine-readable source:** the documented command, hook, API, file, or JSONL
   surface Tokenmon would observe.
2. **Schema sample:** a small redacted event or usage sample with only required
   fields.
3. **Normalized mapping:** how provider fields become Tokenmon usage facts,
   including provider identity, session identity, token totals or deltas, and
   stable event fingerprints.
4. **Idempotency plan:** how duplicate events, repeated scans, app restarts, and
   partial writes avoid double-counting.
5. **Degraded-mode behavior:** what Tokenmon shows when files are missing,
   partial, rotated, malformed, or temporarily inaccessible.
6. **User-facing setup impact:** any onboarding, settings, diagnostics, or
   localization changes.
7. **Tests:** fixtures and automated tests for valid input, malformed input,
   duplicate replay, missing data, and diagnostics output.

---

## 4. Review Bar

Provider-specific code should stay in provider or tightly scoped setup surfaces.
The encounter engine, capture logic, Dex state, and other gameplay rules must
remain provider-neutral.

Maintainers may ask for a smaller first PR, such as:

- documentation and fixtures only
- source locator only
- parser/backfill adapter only
- diagnostics-only support before gameplay ingestion

This keeps provider changes reviewable and avoids shipping a broad integration
whose source contract is still unclear.

---

## 5. Not Accepted

Provider proposals should not:

- depend on scraping provider UI text
- depend on undocumented private file layouts without a stability argument
- silently mutate global provider settings or shell configuration
- install maintainer-only workflow assets
- treat prompt or response text as gameplay input
- add provider-specific behavior to provider-neutral domain logic

If a provider needs special handling, document it at the adapter boundary and
show the degraded behavior in tests.
