---
name: mix
description: >
  Activate multiple skills simultaneously and compose their behaviors.
  Use when the user invokes /mix followed by skill names (e.g., /mix caveman aceopti).
  Stacks active skill rules, resolves conflicts by priority, persists across turns.
  Trigger: "/mix", "combine skills", "use X and Y together", "activate multiple skills".
---

## What /mix does

`/mix <skill1> <skill2> ...` activates all listed skills at once. Their rules stack. Each skill's behavior stays active simultaneously for the rest of the session.

## Invocation

```
/mix caveman aceopti
/mix aceopti acesidekick
/mix caveman aceopti acesidekick
```

## How to compose

When multiple skills activate, apply ALL their rules simultaneously. Where rules conflict, use this priority order (highest wins):

| Priority | Rule type |
|---|---|
| 1 | Safety / security / irreversible-action rules |
| 2 | Output format rules (structure, length) |
| 3 | Communication style rules (tone, compression) |
| 4 | Default behavior |

**Examples of stacking:**

- `caveman` + `aceopti` → terse caveman fragments AND answer-first structure AND no trailing summaries AND batch tool calls
- `aceopti` + `acesidekick` → optimized token structure AND delegate sub-tasks to local LLM where appropriate
- `caveman` + `aceopti` + `acesidekick` → all three active: compressed output, optimized structure, local LLM delegation

## State tracking

After `/mix`, output one confirmation line listing active skills:

```
Mix active: [skill1, skill2, ...]. Rules stacked.
```

Persist all activated skills until user says `/mix reset`, `stop <skillname>`, or session ends.

## Deactivation

- `/mix reset` — clear all mixed skills, return to defaults
- `stop <skillname>` — deactivate one skill, keep others
- `/mix` with no args — show currently active skills

## Conflict resolution examples

| Conflict | Resolution |
|---|---|
| caveman says "fragments OK" vs aceopti says "numbered steps for sequences" | Use numbered steps (safety/clarity wins over compression) |
| caveman says "drop articles" vs aceopti says "structured headers" | Keep headers, drop articles inside them |
| Two skills both affect response length | Shorter wins unless clarity requires more |

## What you should NOT do

- Do not re-introduce filler that an active skill strips
- Do not ignore one skill's rules because another is also active
- Do not ask the user to pick — apply both
