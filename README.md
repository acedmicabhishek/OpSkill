# OpSkill

Multi-skill plugin for Claude Code and AI editors. Compose skills, optimize output, and offload work to local LLMs.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/abhishekanand-arch/OpSkill/main/install.sh | bash
```

Auto-detects and installs for: **Claude Code, Cursor, Windsurf, Cline, Roo, GitHub Copilot, Gemini CLI, Zed**

Restart your editor after install.

---

## Skills

### `/mix` — Multi-skill composer

Activate multiple skills simultaneously. Rules stack. Conflicts resolve by priority: safety > structure > compression.

```
/mix caveman aceopti
/mix aceopti acesidekick
/mix caveman aceopti acesidekick
/mix reset          ← clear all
```

---

### `/aceopti` — Optimized response mode

Best results at lowest token cost. Answer-first. Batched tool calls. No trailing summaries. No re-reads.

**Three thinking modes:**

| Mode | Command | Behavior |
|---|---|---|
| No thinking | `/aceopti` or `/aceopti fast` | Extended thinking OFF. Direct answers only. Maximum speed and token savings. |
| Think like Ace | `/aceopti ace` | No thinking needed — Ace already has the answer. Diagnoses the flaw in your prompt, clarifies what you actually need, gives a better solution than what you asked for. Senior dev mode. |
| Default Claude thinking | `/aceopti deep` | Full reasoning trace ON. Used when problem is genuinely ambiguous or high-stakes. |

**Always applies (all modes):**
- Answer before explanation
- Tables and bullets over prose
- Batch independent tool calls
- No re-read after edit
- No trailing summaries
- No filler transitions

---

### `/aceopti-setup` — Project onboarding assistant

One-time setup that interviews the agent about the project, builds a structured context snapshot, and stores it in cache/memory for all future sessions.

Runs a guided question sequence:
1. What is this project? (type, stack, scale)
2. What is the current task or goal?
3. What areas of the codebase are in scope?
4. What constraints exist? (perf, security, style, deadlines)
5. Who are the stakeholders / consumers of this code?
6. What is the definition of done?

Stores answers as a structured context block in project memory. All future skills load this context automatically — no re-explaining the project each session.

```
/aceopti-setup          ← run full interview
/aceopti-setup refresh  ← update existing context
/aceopti-setup show     ← print current context snapshot
```

---

### `/acesidekick` — Local LLM sidekick

Routes cheap, mechanical tasks to a local LLM (Ollama, LM Studio, llama.cpp). Keeps reasoning, architecture, and correctness tasks on the main model. Uses vector DB for semantic context retrieval. Cache-aware prompt structure.

**Delegate to local LLM:**
- File summarization, log parsing, regex generation
- Template filling, docstring generation, rename suggestions
- SQL boilerplate, test stubs, changelog from diff

**Keep on main model:**
- Bug root cause, architecture decisions, security review
- Cross-file refactor planning, complex state debugging

**Supported local runtimes:**
- Ollama → `http://localhost:11434`
- LM Studio → `http://localhost:1234/v1`
- llama.cpp server → `http://localhost:8080`

**Vector DB support:** ChromaDB, LanceDB, Qdrant

```
/acesidekick            ← auto mode (routes + reports)
/acesidekick light      ← suggestions only, no auto-routing
/acesidekick strict     ← offload everything possible
/acesidekick off        ← disable, all tasks back to main model
```

---

### `/caveman` — Ultra-compressed output

Not built here. Made by [@JuliusBrussee](https://github.com/JuliusBrussee/caveman). Install separately. Composes with all OpSkill skills via `/mix`.

---

## Skill composition examples

| Goal | Command |
|---|---|
| Fast + compressed | `/mix caveman aceopti` |
| Full project context + optimized | `/aceopti-setup` then `/aceopti ace` |
| Local LLM + compressed output | `/mix caveman acesidekick` |
| Everything | `/mix caveman aceopti acesidekick` |

