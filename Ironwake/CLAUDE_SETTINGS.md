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
- **⚠️ If M authorizes creating a sprite asset via the pipeline (write `.yy` + add a `.yyp`
  resource line), GameMaker MUST be fully CLOSED first.** GM rewrites `Ironwake.yyp` from its
  in-memory model on save/F5 and will silently CLOBBER external entries, orphaning the sprite →
  runtime "Variable spr_ability_x not set before reading it". Do it with GM closed, then reopen.
  PNG-only overwrites of an EXISTING registered sprite (swap the composite + `layers/.../*.png`)
  are safe anytime — no `.yyp` change. (07-18 lesson.)

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

### Scrollable Overflow + Visual-First UI (MANDATORY — added 2026-07-27, M's standing order)
M: "prioritize making a submenu or pop up etc — anything with abundant information or
lists — to be scrollable with a vertical scroll bar... we are working off too much text
on screen and less ui/visual communication."
1. **Any submenu/popup/panel with abundant info or a list that can overflow gets vertical
   scrolling WITH a visible scroll bar** (track + proportional thumb). A "+N more" text
   line with no way to reach the tail is a DEFECT (07-27: Bairc feed pouch).
2. **Page/scroll size must come from the MEASURED visible row capacity**, never a
   hard-coded row count — squeezed boxes shrink capacity and orphan the tail.
3. **Prefer visual/interactive communication over walls of text**: layered inspection
   (the Tab-on-creatures pattern), item cards shown visually, two-step screens with
   animation + SFX for meaningful actions — instead of packing everything into one
   text-dense panel.
4. **Destructive or irreversible one-click actions (rerolls, spends, sacrifices) need a
   confirmation step or secondary screen** (07-27: Dorn reforge one-clicked a legendary).
5. **Every "checkout" confirm (store/shop/trainer spends) is a BORDERED OVERLAY POPUP
   with CONFIRM/CANCEL buttons — never a question in the bottom notification line**
   (M 07-27: "that should be our default with any checkout store/shop/trainer mechanic").
   Use `ui_draw_checkout_confirm()` (scr_ui) and make the owning Step MODAL while armed
   — swallow nav/tabs/row toggles so the pending action can't shift under the popup
   (the inline-confirm transmute bug: Enter deselected the rune it was committing).

### Touch Compatibility Check (MANDATORY — added 2026-07-18, M's standing order)
Ironwake ships on Android. M hit a **softlock** on the new whetstone shrine because it had
NO touch controls — he only escaped via the on-screen d-pad. That must never happen again.

**Every new or changed interactive screen/feature gets a touch pass IN THE SAME TASK — automatic,
no prompt needed.** Before marking any UI work complete:
- **Every verb needs a touch path**: a direct tap target, an ACTIONS-chip entry, or confirmed
  d-pad reachability. Keyboard/gamepad-only verbs are a DEFECT on a shipping mobile title.
- **Hit-testing lives in the DRAW events** (draw + hit-test together, like the chip bar), NOT
  Step. Step-only greps give FALSE POSITIVES — the 07-17 audit "found" walls at the shrine,
  event choices, and level-up that were all actually touch-complete in Draw.
- **Check the letter-hotkey pattern specifically**: single-touch only maps to mouse, which only
  covers on-screen buttons — so bare letter hotkeys (B/F/R/C/Tab) are invisible to touch users.
- **Tab-equivalents**: any "hold/press Tab to inspect" affordance needs a long-press or explicit
  touch target (M 07-18: Bairc pet inspect + loadout abilities both missing one).
- Gate touch-only UI on `input_device() == 2`.

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

### Icon Art Rules (MANDATORY — added 2026-07-17, M's standing order)
Too many credits were burned on icons whose art doesn't read as the thing they name.
1. **Every icon must sensibly match its name/effect.** The art has to read as the ability/
   trait/item it represents (a diseased finger for Plague Touch, a crosshair for Snipe — not
   a cat in a box or a reused blood-eye). If the subject is wrong, it's a defect regardless
   of individual art quality.
2. **Every icon must be boxed + bordered in the shipped frame style** — the baked-in beveled
   dark border the Pass-2 set has (see spr_ability_snipe as the reference). Bare full-subject
   art with no frame (e.g. Compounding Dread, Winter's Bite) is a defect; fix by compositing
   onto the standard frame (free, PIL) or regenerating with a bordered style ref.
3. **M must approve every icon before it ships — in BATCHES.** Candidates go to `_for_review\`;
   no icon reaches the game unapproved. Scope the regen COUNT with M and get an explicit YES
   before generating a single one (ties to COST DISCIPLINE hard rules).
4. **Prefer REMAP over REGEN.** Reuse an existing sensible in-game icon via
   `ui_ability_icon_sprite()` / the trait map (free, one-line .gml swap) whenever one fits;
   only regenerate when nothing existing fits. Style new art from 2-4 shipped in-game icons
   (see the style-consistency recipe).

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
