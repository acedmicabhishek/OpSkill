# CLAUDE.md — OpSkill

## Project overview

OpSkill = three skills that compose with each other and with caveman.

- `/mix` — activate multiple skills simultaneously, stack their rules
- `/aceopti` — answer-first, batched tools, no summaries, max density
- `/acesidekick` — route cheap tasks to local LLM, use vector DB for retrieval, cache-aware prompting

## Skill file structure

Each skill lives in `skills/<name>/skill.md`. Frontmatter fields required:
- `name` — matches directory name
- `description` — one paragraph, includes trigger phrases

## Design constraints

**mix**: conflict resolution priority = safety > structure > compression. Never ask user to choose between active skills.

**aceopti**: "best result" means correct + dense. Never sacrifice correctness for token savings. When a numbered sequence is clearer than fragments, use it even if caveman is also active.

**acesidekick**: local LLM delegation is opt-in via the skill. Never silently route tasks without informing the user. Always report what was delegated.

## What NOT to add

- Do not add hooks unless there is a specific behavioral trigger that cannot be expressed in skill.md prose
- Do not add install scripts until skills are validated
- Do not add more skills until the three core ones are proven
