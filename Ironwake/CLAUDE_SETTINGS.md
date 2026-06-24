# Claude Code – Permanent Settings & Context Management

**This file stays in the Ironwake project folder permanently. Reference it at the start of every session.**

---

## Context Efficiency Rules

### Auto-Compact Strategy
**Goal**: Preserve token efficiency and credits. Compact early and often.

1. **Monitor context usage**:
   - After every 3–4 code implementations, check remaining context
   - If context usage > 30%, propose compaction (don't wait for 50%)
   - If usage > 40%, stop current task and compact immediately

2. **Compaction workflow**:
   - Summarize completed work in 2–3 sentences
   - List files modified and their purpose
   - Clear all conversation history, reset to fresh context
   - Paste summary + next task document into new context
   - Continue without interruption

3. **Never accumulate context**:
   - Don't chain multiple tasks in a single context window
   - Each task gets its own clean context
   - Exception: Short sub-tasks (< 100 lines) can batch if budget allows

4. **Pre-compaction checklist**:
   - [ ] Code tested and working
   - [ ] File changes saved
   - [ ] Task marked as complete in task doc
   - [ ] Summary written (2–3 sentences)
   - [ ] Ready to hand off to next context

---

## Implementation Rules

### File Management
- **Only edit `.gml` files** — never touch `.yy` or `.yyp` files
- **Create new objects/rooms in IDE first**, then write code
- **Always design before coding**: Agree on mechanics/numbers with M before writing any code

### Design Lock
- All task documents are **design-locked** — no re-design loops
- If code reveals a design issue, flag it to M but implement as documented
- M's mid-task changes get added to next task, not inserted mid-task

### Code Quality
- Clear variable names (`buff_duration_remaining`, not `dur`)
- Comment non-obvious logic
- Test before marking complete
- Keep GML files under 500 lines when feasible (split into functions if needed)

### Communication with M
- Start each task with: "Starting [TASK_NAME]. Need clarifications on: [X, Y, Z]?" (if any)
- End each task with: "Completed [TASK_NAME]. [2-sentence summary]. Ready for compaction?"
- Flag blockers immediately: "Can't proceed without [info]"

---

## Project Context
- **Engine**: GameMaker Studio 2
- **Project Path**: `C:\Users\miles\GameMakerProjects\Ironwake\`
- **Code Location**: `.gml` files in Ironwake/scripts and Ironwake/objects
- **Build**: Ready for GitHub + itch.io (HTML5 build at outlawstar.itch.io/ironwake)

---

## Current Systems (Reference)
- **Combat**: 3 AP action economy, turn-based combat loop
- **Equipment**: Tabbed loadout system at dungeon gate, stash-based inventory
- **Progression**: L1–15 leveling, XP/gold drops, loot screen post-combat
- **Items**: Hybrid affix system, hand-authored legendaries, vendor shops (Petra/Dorn)
- **Hub**: Dungeon gate with character menu, stash, shops, loadout screen

---

## Efficiency Metrics
Track these to measure session quality:
- **Tokens used per task**: Aim for < 8k per task (smaller = better)
- **Compactions per session**: 2–3 is good
- **Code quality**: No bugs requiring rework
- **Time-to-completion**: Task duration vs. estimated

---

**Remember**: Early compaction = more tasks completed per credit unit. Don't accumulate context to "save time" — it costs more overall.
