---
name: acesidekick
description: >
  Delegates appropriate sub-tasks to a local LLM via Ollama and uses vector embeddings
  for semantic search. Uses Bash tool to call Ollama API directly.
  Default models: qwen2.5-coder:7b (tasks), qwen2.5-coder:14b (heavy), nomic-embed-text (embeddings).
  Use when user says "acesidekick", "use local llm", "sidekick mode",
  "offload to local", or invokes /acesidekick.
---

## Purpose

acesidekick = route cheap tasks to local Ollama, keep reasoning here. Uses Bash tool to call Ollama API. Reports what was delegated.

## Default models

| Role | Model | When |
|---|---|---|
| Sidekick | `qwen2.5-coder:7b` / `:14b` | ONE tiny task at a time (see size cap) |
| Embeddings | `nomic-embed-text` | Semantic search over an index |

> ⚠️ **The local models are weak.** Tested: `qwen2.5-coder:14b` hallucinated freely on anything larger than a single unit. Do not trust either model with multi-part output, whole files, or anything requiring it to "hold" a spec. Treat them as autocomplete, not as an engineer.

## Size cap — delegate ONE tiny unit at a time

Hard rule: a delegated task must be small enough that **its entire output is verifiable in seconds at a glance.**

| ✅ Delegate (tiny unit) | ❌ Too big (keep on main) |
|---|---|
| One docstring for one function | A whole file of docstrings in one call |
| One regex | A parser |
| One boilerplate snippet (getter, DTO) | A multi-section doc (API ref, guide) |
| One-line summary of one file | A 400-line reference |
| Rename suggestions for one symbol | A cross-file refactor |

If a job is N tiny units (e.g. docstrings for 20 functions), **split into N separate one-unit calls** and run them in parallel — never one big "do all 20" prompt. One big prompt = the model drifts and invents. N small prompts = each is checkable.

## Core principle: impact × quality need

**Delegate to sidekick when BOTH hold:**
1. **Low impact** — a mistake is cheap to catch and fix, doesn't break the build or corrupt logic.
2. **Best quality not required** — "good enough" output is acceptable; you don't need the strongest model.

If both true → sidekick. If either fails → main model.

| | Low impact | High impact |
|---|---|---|
| **Quality optional** | ✅ sidekick (docs, boilerplate, stubs) | ❌ main (refactor touching many files) |
| **Quality critical** | ❌ main (public API signature) | ❌ main (lock-free, money math) |

### Two things sidekick is for

**1. Minimal / low-stakes tasks** — docstrings, comments, boilerplate, test stubs, regex, renames, file summaries, changelog. Output accepted as-is.

**2. Parallel processing** — fan out many independent mechanical tasks at once. 20 files needing docstrings → fire 20 local calls in parallel, each $0. Main model would do these serially and billed. This is the biggest win.

### Feed raw source, never a paraphrase

If the output must match exact symbols in the codebase — function names, field names, enum values, signatures — paste the **actual source files verbatim** into the prompt. Never feed a hand-written description of the code.

**Why:** a paraphrase lets the local model pattern-match "plausible" C++/Python that diverges from reality. Real failure: fed qwen a text summary of an LOB → it emitted `add_order()` (real: `add()`), `set_on_fill()` (real: public field `on_fill`), `is_armed()` (real: `is_active()`), invented `Fill::notional`, wrong enum values. Every signature wrong. Whole doc thrown out.

Rule: description-fed generation = hallucinated symbols. Source-fed = grounded. If you can't fit the source in the prompt, the task is too big for sidekick — keep it on main.

### Doc types — not all docs are equal

"Docs" is not automatically a sidekick task. Split by whether the doc must match exact code:

| Doc type | Delegate? |
|---|---|
| Architecture overview, design rationale, conceptual prose | ✅ yes — low impact, no exact symbols |
| README intro, project pitch | ✅ yes |
| API reference (exact signatures, fields, enums) | ❌ no — signature-critical, you verify every line |
| Tutorial with runnable code examples | ❌ no — invented APIs won't run |

Real test outcome: `ARCHITECTURE.md` (conceptual) shipped with minor fixes. `API_REFERENCE.md` + `DEVELOPER_GUIDE.md` (signature + code) were full rewrites on main. Delegate the conceptual one only.

### The confirm gate

Before delegating, one check:

> **Will I ship the local output without reading it line-by-line?**

- **Yes** → delegate. Real saving.
- **No** → don't. If you review every line for bugs, you pay main-model tokens for review + rework anyway. Local draft = throwaway. Net ≈ 0.

Failure mode to avoid: delegating correctness-critical code (lock-free atomics, UB-prone C/C++, matching logic, money math) to get a "draft." Subtle bugs → you rewrite on main model → saved nothing. Write it on main directly.

## What to delegate vs keep

**Delegate to local LLM:**

| Task | Model to use |
|---|---|
| Docstring / comment generation | `qwen2.5-coder:7b` |
| Test stub generation | `qwen2.5-coder:7b` |
| Regex generation | `qwen2.5-coder:7b` |
| Rename suggestions | `qwen2.5-coder:7b` |
| SQL boilerplate | `qwen2.5-coder:7b` |
| File summarization | `qwen2.5-coder:14b` |
| Changelog from diff | `qwen2.5-coder:14b` |
| Template filling | `qwen2.5-coder:14b` |
| Log parsing / extraction | `qwen2.5-coder:14b` |

**Keep on main model (never delegate):**
- Bug root cause analysis
- Architecture decisions
- Security review
- Cross-file refactor planning
- Complex debugging
- Lock-free / concurrent code (CAS, atomics, memory ordering)
- UB-prone C/C++ (pointer math, `clz`/`clzll` on 0, signed overflow)
- Correctness-critical logic (matching engines, money math, percentile/stat cumulation)
- Any code where you'll read every line before trusting it

## How to call Ollama (use Bash tool)

When delegating a task, use the Bash tool with this exact pattern:

```bash
curl -s http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:7b",
    "prompt": "<your full task prompt here>",
    "stream": false
  }' | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"
```

For heavier tasks:
```bash
curl -s http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:14b",
    "prompt": "<your full task prompt here>",
    "stream": false
  }' | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"
```

After Bash call returns: use the output directly. Report one line: `[sidekick] qwen2.5-coder:7b → <what was done>`

## Parallel processing (the big win)

For N independent mechanical tasks, fire them concurrently — don't serialize. Ollama queues but background `&` lets you launch all, then collect.

Example: docstrings for many functions/files at once.

```bash
# Write each task prompt to a file, run all in parallel, collect outputs
mkdir -p /tmp/sidekick && cd /tmp/sidekick

run_task() {
  local id="$1" prompt="$2"
  curl -s http://localhost:11434/api/generate \
    -d "{\"model\":\"qwen2.5-coder:7b\",\"prompt\":$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$prompt"),\"stream\":false}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])" > "out_$id.txt"
}

# launch all in background
run_task 1 "Write a JSDoc for: function add(a,b){return a+b}" &
run_task 2 "Write a JSDoc for: function sub(a,b){return a-b}" &
run_task 3 "Write a JSDoc for: function mul(a,b){return a*b}" &
wait   # block until all done

# collect
for f in out_*.txt; do echo "=== $f ==="; cat "$f"; done
```

Each call costs $0. Main model billed for zero generation — only the final Edit applying results. Report: `[sidekick] qwen2.5-coder:7b ×N parallel → <what>`.

Note: a single 24GB machine runs one model instance; Ollama serializes GPU work but the `&` + `wait` pattern still overlaps curl/IO and keeps the queue full. For true throughput, keep prompts small and batched.

## Semantic search with nomic (on-demand, no DB)

**When to use this — the trigger:**
- User asks a **conceptual** code-location question: "where does it handle X", "what code is responsible for Y", "find the part that does Z" — where the words they use may NOT appear literally in the code.
- `grep`/`Glob` already won for **exact strings/symbols** — use those first. Reach for nomic only when lexical search misses because the concept is phrased differently than the code.

**How it works:** build a throwaway index in `/tmp`, embed every chunk + the query with `nomic-embed-text`, rank by cosine. No ChromaDB, no persistence — disposable per query.

```bash
mkdir -p /tmp/sidekick && cd /tmp/sidekick

# 1. Collect searchable chunks (function sigs / def lines + file:line). Tune the grep.
grep -rn -E '^(def |class |[a-zA-Z_].*\()' --include=*.py --include=*.hpp --include=*.cpp . \
  2>/dev/null | head -400 > chunks.txt

# 2. Embed chunks + query, cosine rank — single python block, one nomic call per line
python3 - "find code that handles order matching and fills" <<'PY'
import sys, json, urllib.request, math
query = sys.argv[1]
def embed(text):
    req = urllib.request.Request("http://localhost:11434/api/embeddings",
        data=json.dumps({"model":"nomic-embed-text","prompt":text}).encode(),
        headers={"Content-Type":"application/json"})
    return json.load(urllib.request.urlopen(req))["embedding"]
def cos(a,b):
    d=sum(x*y for x,y in zip(a,b)); na=math.sqrt(sum(x*x for x in a)); nb=math.sqrt(sum(y*y for y in b))
    return d/(na*nb+1e-9)
qv = embed(query)
rows = [l.rstrip() for l in open("chunks.txt") if l.strip()]
scored = sorted(((cos(qv, embed(r)), r) for r in rows), reverse=True)[:8]
for s,r in scored: print(f"{s:.3f}  {r[:120]}")
PY
```

Output = top-8 `file:line` matches ranked by meaning. Then **Read those files** to confirm. Report: `[sidekick] nomic-embed-text → semantic search, top hit <file:line>`.

**Cost note:** embedding is cheap + local ($0). But it's one nomic call per chunk — keep `chunks.txt` ≤ ~400 lines or it's slow. For big repos, pre-filter with grep first, then semantic-rank the survivors.

**Don't bother when:** exact symbol known (use grep), repo tiny (just read it), or question is non-semantic (use Glob).

## Check Ollama is running

Before first delegation each session, verify with Bash tool:

```bash
curl -s http://localhost:11434/api/tags | python3 -c "import sys,json; models=[m['name'] for m in json.load(sys.stdin)['models']]; print('Ollama running. Models:', models)"
```

If this fails: tell user `ollama serve` is not running. Do NOT attempt delegation.

## Activation behavior

On `/acesidekick`:
1. Run Ollama check (Bash tool, silently)
2. Output one line:

```
acesidekick active. Ollama: [running — models: qwen2.5-coder:7b, qwen2.5-coder:14b, nomic-embed-text] / [NOT running — run: ollama serve]
```

## Levels

| Level | Behavior |
|---|---|
| `/acesidekick light` | Suggest what to delegate, ask confirmation before each Bash call |
| `/acesidekick auto` (default) | Delegate automatically, report after |
| `/acesidekick strict` | Delegate everything possible without asking |

## Example delegation flow

User: "add docstrings to all functions in utils.js"

1. Read utils.js (Read tool)
2. For each function, call Bash tool with qwen2.5-coder:7b:
   ```
   prompt: "Write a JSDoc docstring for this function. Return only the docstring, nothing else:\n\n<function code>"
   ```
3. Edit utils.js with returned docstrings (Edit tool)
4. Report: `[sidekick] qwen2.5-coder:7b → generated docstrings for 8 functions in utils.js`

## Deactivation

`/acesidekick off` — stop delegating, all tasks back to main model.
