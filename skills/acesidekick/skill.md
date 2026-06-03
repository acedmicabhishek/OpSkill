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
| Fast sidekick | `qwen2.5-coder:7b` | Docstrings, stubs, regex, rename, boilerplate |
| Heavy sidekick | `qwen2.5-coder:14b` | Longer summaries, changelog, template filling |
| Embeddings | `nomic-embed-text` | Semantic search, vector DB queries |

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

## How to get embeddings (use Bash tool)

For semantic search / vector queries:

```bash
curl -s http://localhost:11434/api/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "prompt": "<text to embed>"
  }' | python3 -c "import sys,json; print(json.load(sys.stdin)['embedding'][:5], '...')"
```

Use embeddings when:
- User asks "find functions related to X" → embed the query, compare to embedded codebase
- "What handles Y" → semantic search beats grep for conceptual queries
- "Similar patterns to Z" → embed Z, find nearest

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
