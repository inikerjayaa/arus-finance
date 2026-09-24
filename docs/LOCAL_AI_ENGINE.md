# SAKU Local Intelligence Engine

Status: ARCHITECTURE CONTRACT — AI remains capability-gated until each use case has schema, error, privacy, benchmark, fallback, and regression tests.

## Goal

Add useful intelligence without changing SAKU's core product contract: finance data stays device-owned, core features work offline, no login/server/cloud/hosted-AI dependency is required, and user financial data is never silently exported.

The design is informed by `karpathy/llm.c`: keep the execution path understandable, benchmarkable, dependency-light, and explicit about memory/compute. We borrow the engineering principles, not the assumption that a training stack belongs inside a phone.

## Hard rule: training and inference are different products

### Off-device / build-time only
- training and fine-tuning;
- dataset preparation and labeling;
- tokenizer/model conversion;
- quantization experiments;
- model evaluation and red-team suites;
- generation of signed model manifests and golden test vectors.

### On-device only
- bounded inference;
- deterministic feature extraction;
- tiny local ranking/classification models;
- local embeddings only when memory/size budgets pass;
- user-profile adaptation through local counters/statistics where possible;
- no gradient training of LLMs on the phone.

## Intelligence ladder

Always choose the lowest tier that solves the problem well.

1. **Tier 0 — deterministic intelligence**
   - rules, statistics, recency/frequency, robust thresholds, anomaly bands;
   - zero model download, instant startup, easy to audit.
2. **Tier 1 — micro ML**
   - small linear/tree/classifier/ranker models with fixed feature vectors;
   - weights bundled locally and versioned;
   - preferred for categorization, ranking and anomaly scoring.
3. **Tier 2 — compact semantic model**
   - quantized embeddings or a very small transformer only for tasks where semantics materially improve quality;
   - bounded context and bounded output;
   - lazy-loaded and unloadable.
4. **Tier 3 — optional external augmentation**
   - never required for core behavior;
   - must be explicit opt-in and privacy-transparent;
   - not part of the default local engine.

## First SAKU use cases

### A. Smart category suggestion
Input: local transaction text, merchant/payee alias, amount band, account type, prior user corrections.
Output: top 1–3 category suggestions with confidence.
Default implementation: Tier 0 + Tier 1. No generative model required.

### B. Merchant / description normalization
Input: raw transaction description.
Output: local canonical display label and alias mapping suggestion.
Default implementation: deterministic normalization + local alias learning. Semantic model only if measurable improvement justifies cost.

### C. Spending anomaly hints
Input: local ledger aggregates only.
Output: explainable signals such as unusually high amount, new merchant, unusual category frequency, or deviation from rolling baseline.
Default implementation: robust statistics first. No LLM needed.

### D. Search intent assist
Input: user query such as `makan bulan lalu di bawah 100 ribu`.
Output: a structured local filter expression.
Default implementation: grammar/parser + small intent classifier. Never allow generated SQL to execute directly.

### E. Budget / cash-flow insight text
Input: already-computed local facts.
Output: short templated explanation generated from verified numeric facts.
Default implementation: deterministic templates first. A compact generator may only verbalize facts already produced by trusted finance logic; it must never calculate balances itself.

## Runtime architecture

`UI -> LocalIntelligenceFacade -> UseCase Engine -> Feature Extractor -> Tier 0/1/2 Runtime -> Result Validator -> UI`

Financial repositories remain authoritative. AI output is advisory and cannot directly mutate canonical ledger data.

### Required runtime properties
- lazy initialization;
- no model load during cold start unless the first visible screen needs it;
- one shared runtime instance per model family;
- bounded input length;
- bounded output length;
- cancellation support;
- newest-request-wins for interactive suggestions;
- deterministic fallback when runtime/model is unavailable;
- model unload under memory pressure;
- no background busy-loop inference.

## Model artifact contract

Every bundled model must have a manifest containing:
- model id and semantic version;
- task id;
- architecture/runtime type;
- quantization type;
- tokenizer/version if applicable;
- file size;
- SHA-256;
- expected peak RAM class;
- minimum supported device/runtime version;
- golden input/output vectors;
- privacy classification;
- fallback behavior.

A checksum mismatch disables the model and activates the non-AI fallback. It must never corrupt or block finance data access.

## Mobile budgets

These are release gates, not aspirations. Any model exceeding a budget requires an explicit architecture review.

- cold-start regression caused by AI: target ~0 ms because models are lazy-loaded;
- Tier 1 model artifact: prefer < 5 MB;
- Tier 2 semantic artifact: prefer <= 50 MB, hard review above this;
- peak incremental RAM for ordinary AI interaction: target <= 128 MB on supported low/mid devices;
- interactive suggestion latency: target p50 < 100 ms for Tier 0/1 and < 500 ms for Tier 2 on reference Android device;
- no mandatory network round-trip.

Exact thresholds may be tightened after device benchmarking; they must never be silently loosened.

## Privacy and safety

- raw finance data stays local by default;
- model input is ephemeral unless the feature explicitly needs persistent local state;
- logs must never contain full transaction descriptions, balances, backup keys, PINs, or secure-storage secrets;
- local learning state must be erasable with user data;
- AI confidence must never be presented as financial truth;
- suggestions that could change financial records always require normal product confirmation/edit flows.

## Testing contract

Every AI-assisted feature must include:
- deterministic fallback tests;
- golden inference tests;
- corrupted/missing-model tests;
- low-memory/unavailable-runtime tests;
- cancellation and rapid-repeat tests;
- privacy/logging tests;
- regression test proving ledger balances are identical with AI enabled vs disabled;
- device benchmark evidence before a model becomes default-on.

## What from llm.c we deliberately do NOT copy into the mobile runtime

- CUDA training stack;
- optimizer/backpropagation code;
- multi-GPU/multi-node training;
- heavyweight Python/PyTorch runtime dependencies;
- phone-side LLM training.

Those ideas belong in an optional research/training repository or build pipeline, not the production SAKU app.

## Delivery sequence

1. Lock this contract and keep current finance/UAT fixes higher priority.
2. Implement a runtime-neutral `LocalIntelligenceFacade` with Tier 0 fallbacks only.
3. Ship first measurable use case: category suggestion.
4. Add benchmark harness and model manifest validation.
5. Introduce Tier 1 model only if it beats deterministic baseline on a frozen evaluation set.
6. Introduce Tier 2 semantic runtime only if a concrete use case cannot meet quality with Tier 0/1.
7. Keep AI removable: disabling/removing every model must leave SAKU fully functional.
