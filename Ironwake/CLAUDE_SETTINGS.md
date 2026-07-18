# Claude Code – Permanent Settings & Context Management

**This file stays in the Ironwake project folder permanently. Reference it at the start of every session.**

---

## COST DISCIPLINE — HARD RULES (MANDATORY — added 2026-07-17, M's standing order)

M pays real money — subscriptions have been MAXED OUT and hundreds of dollars burned through
wasted spend (PixelLab silently wasting credits for WEEKS before M caught it by hand; a single
session burned ~450k tokens across background agents that delivered almost nothing). These are
not guidelines. Violating them costs M real money.

1. **NO background agents / forks / subagents without M's explicit per-task YES.** A `fork`
   inherits the ENTIRE current context as its starting cost, so two forks ≈ triple the token
   spend before they read a single line — and they can silently FAIL or confabulate success
   (07-17: a fork reported combat wiring "done" and had written none of it). Default to INLINE.
   If a task seems to warrant an agent, ASK FIRST and state the expected cost.
2. **NO AI generation (PixelLab / ElevenLabs / any paid API) without M's explicit per-batch
   YES.** Check the balance/meter at start and report it. Never run generation loops. One
   candidate, then audition. 2 misses = STOP. (See "AI Generation Credit Budgets" below.)
3. **Any action expected to consume large tokens or credits requires M's OK BEFORE running it**
   — not after. When in doubt, ask.
4. **Cheapest tool for the job.** Targeted `Grep` over broad `Read`; read only the spans you
   need; don't re-read files already in context; verify on disk with a cheap grep rather than
   trusting an agent's narrative.
5. **Report spend honestly** at wrap-up (tokens where visible, gen credits always). If something
   was wasteful, say so plainly.

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

### UI Collision Check (MANDATORY — added 2026-07-09)
Whenever adding or changing any on-screen text or UI element:
- **Verify nothing collides or overlaps** with neighboring text, boxes, frames, or borders at 1920×1080
- Check the **longest realistic string** (longest item/ability/pet name, max stack counts, 4-digit gold), not just the happy case
- Check **list overflow**: when rows exceed the visible area, scrolling/indicators must work and rows must not run past the panel
- Measure with `string_width()`/`string_height()` against the actual box rect before placing — don't eyeball offsets
- Too much time has been lost fixing minor overlap errors across pages; catch them before handoff

### Reference Sync (MANDATORY — added 2026-07-09)
Whenever a game mechanic changes, sweep and update **every in-game reference** to it in the same task:
- Compendium/codex entries, tutorials, ability/trait/item descriptions, tooltips, shop text, key legends
- Grep for the old numbers/terms across scripts and objects before marking complete
- A mechanic change is not done until the game nowhere describes the old behavior

### AI Generation Credit Budgets (MANDATORY — added 2026-07-14)
M pays real money for generation subscriptions. Credits are NEVER burned on
unaudited re-rolls (lesson: PixelLab 610-gen session, ~440 wasted).

**ElevenLabs (Creator $22/mo):**
- Call `check_subscription` at session start AND wrap-up; report balance + spend to M both times
- Session cap: **~10,000 credits without M's explicit sign-off**
- **ONE candidate per sound, then audition** (listen / `_for_review\`) before any iteration
- **2 misses on the same prompt = STOP** — rework the approach or use owned Asset_Library packs
- Set the **shortest sensible explicit duration** (combat SFX ~0.5–1.5s); never auto-duration for short effects
- No unattended/scripted generation loops

**PixelLab:** hard cap ~100 gens/session without sign-off; 2 failed rolls = stop
and switch approach; report spend every wrap-up.

### _for_review Lifecycle (MANDATORY — added 2026-07-17, M's standing order)
`Ironwake\_for_review\` holds ONLY material actively awaiting M's review. When a
revision round completes, clean it automatically — no prompt needed:

1. **A review item is RESOLVED when** M has picked/approved it AND the pick is
   imported + committed, or M has rejected it.
2. **Before deleting anything**, verify the imported asset actually exists in the
   committed project (sprite folder / sound folder / yyp entry). Never delete the
   only copy of something.
3. **Then delete**: candidate images/sheets, source mp3s whose oggs are committed,
   conversion intermediates (_ogg/_proc), and rejected material.
4. **Never touch `_archive\`** (shipped history — e.g. the Steam 1920×1080
   screenshot crops may be the only local copies) unless M explicitly asks.
5. Report what was removed in the wrap-up summary.

### Screenshots\ Auto-Cleanup (MANDATORY — added 2026-07-17, M's standing order)
`Ironwake\Screenshots\` holds M's bug-report / feedback captures. When the issue a
screenshot documents is RESOLVED (fix applied — verify via F5 when practical), delete
that screenshot automatically — no prompt needed. **Keep** screenshots whose issue is
still open (art redesigns, unfixed bugs) and pure reference shots (store/verification
captures — not bugs). A screenshot is a cheap live re-capture, so deleting a fixed
one is low-risk; if you're unsure a fix fully landed, say so in the summary. Report
which screenshots were removed at wrap-up.

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
