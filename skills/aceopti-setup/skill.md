---
name: aceopti-setup
description: >
  Project onboarding assistant. Interviews the agent about the project with a guided
  question sequence, builds a structured context snapshot, and stores it in project
  memory for all future sessions. All skills load this context automatically.
  Use when user says "aceopti-setup", "set up project context", "onboard project",
  "tell claude about my project", or invokes /aceopti-setup.
---

## Purpose

aceopti-setup = one-time project interview → persistent context snapshot. Every future session starts with full project understanding. No re-explaining. No stale assumptions.

## Invocation

```
/aceopti-setup          ← run full interview
/aceopti-setup refresh  ← update existing context (re-runs questions, keeps unchanged answers)
/aceopti-setup show     ← print current context snapshot without running interview
/aceopti-setup reset    ← delete stored context, start fresh
```

## Interview sequence

Run these questions ONE AT A TIME. Wait for the answer before asking the next. Do not batch questions.

```
1. What is this project?
   → Type (web app / API / CLI / library / mobile / data pipeline / other)
   → Stack (languages, frameworks, databases)
   → Scale (lines of code, team size, traffic/load if relevant)

2. What is the current goal or task?
   → What are we trying to accomplish right now?
   → Is this a new feature, bug fix, refactor, or exploration?

3. What parts of the codebase are in scope?
   → Which directories, modules, or services are relevant?
   → What is explicitly OUT of scope for this session?

4. What constraints apply?
   → Performance targets?
   → Security requirements?
   → Style guide or naming conventions?
   → Deadlines or milestones?

5. Who consumes this code?
   → Internal team? External API users? End users?
   → Any downstream dependencies that could break?

6. What does "done" look like?
   → How will we know the task is complete?
   → Are there tests, metrics, or review criteria?
```

## Output format

After all answers collected, generate a context snapshot in this exact structure and save it to project memory:

```markdown
## Project Context (aceopti-setup)
Generated: <date>

**Project:** <name> — <type>, <stack summary>
**Scale:** <size/team/load>

**Current goal:** <task in one sentence>
**Task type:** <feature | bugfix | refactor | exploration>

**In scope:** <comma-separated list>
**Out of scope:** <comma-separated list>

**Constraints:**
- <constraint 1>
- <constraint 2>

**Consumers:** <who uses this>
**Definition of done:** <criteria>
```

Then output:
```
Context snapshot saved. All skills will load this automatically.
Run /aceopti-setup show to review. /aceopti-setup refresh to update.
```

## How other skills use this context

When aceopti-setup context exists in project memory:
- `/aceopti` loads it before answering — no need to re-explain stack or constraints
- `/acesidekick` uses "in scope" list to limit vector DB queries
- `/mix` passes context to all active skills at composition time

## Caching strategy

The context snapshot is designed to be a stable, long system-prompt prefix. Structure it so the static description (project type, stack, constraints) comes first and the dynamic parts (current goal, current task) come last. This maximizes prompt cache hits across sessions.

## Refresh behavior

`/aceopti-setup refresh` — re-asks goal and scope only:
- Current goal (always re-ask)
- In scope / out of scope (always re-ask)
- Skips: project type, stack, scale, constraints (rarely change)
