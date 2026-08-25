# skills

Personal, tool-agnostic agent skills. This repo is the single source of truth.
Layered:
`global/` primitives everywhere, `engineering/` dev-flow skills per-repo, and
`agents/` personas. [`CLAUDE.md`](./CLAUDE.md) holds the load-bearing
**invariants** (always loaded when this repo is cwd); the fuller architecture,
tiering, and the **router table** live below (read on demand).

## Layout

- **`global/`**: `map`, `grill`, `diverge`, `converge`, `handoff`,
  `skill-setup`, `project-setup`, `standup`, `hotwash`, `branch-prune`,
  `unslop`.
  Symlinked into `~/.claude/skills/`; apply in every repo.
- **`engineering/`**: the dev-flow composition layer: the increment suite
  (`prototype`, `aar`, `audit`, `spec`, `issues`, `implement`, `refactor`, `adr`,
  `codebase-map`, `codebase-grill`, `codebase-review`, `pr-review`, `review`,
  `design`, `update-docs`).
  **Project-scoped**: linked into a repo only when it opts in via `project-setup`.
- **`agents/`**: personas (`@ennio`, `@bit`, `@vitruv`, `@tux`, `@linn`,
  `@radar`). Each Markdown file is one portable prompt; `agents/manifest.json`
  carries shared discovery text. `harness/wire` combines them with native
  metadata and model targets.
- **`hooks/`**: harness guardrails, not skills: shell scripts wired into
  `~/.claude/settings.json`'s `hooks` block. `main-branch-guard.sh` is the local
  half of @tux's floor. Symlinked into `~/.claude/hooks/`.
- **`harness/`**: the capability contract, model map, native configuration,
  protocol adapters, wiring manifests, and the one manifest executor. It owns
  harness mechanics, never copies of canonical behavior.

`map` and `grill` are complements, the general front doors to the `diverge` and
`converge` disciplines, which own the method and the artifact. `skill-setup`
governs how every skill here is authored. All write markdown artifacts into
`~/Dev/notes` following that vault's `_saving.md`.

## How they're wired

Skills reach each harness through direct, gitignored symlinks where native
discovery permits them. Persona files and bounded OpenCode command adapters are
rendered when a runtime cannot import canonical content in the required native
shape. `harness/wire` reads the manifests under `harness/*/wiring.json`; there
is no installer per harness.

```
~/Dev/skills/global/<skill>/SKILL.md   ← source (this repo)
  ↑ symlink
~/.claude/skills/<skill>               ← where Claude Code discovers it (everywhere)

~/Dev/skills/engineering/<skill>       ← source (this repo)
  ↑ symlink (per-skill, opt-in per repo)
<repo>/.claude/skills/<skill>          ← discovered only when that repo is cwd

~/Dev/skills/agents/<agent>.md         ← portable prompt (this repo)
agents/manifest.json + harness metadata + harness/models.json
  ↓ harness/wire render
~/.claude/agents/<agent>.md            ← Claude-native runtime file
~/.config/opencode/agents/<agent>.md   ← OpenCode-native runtime file

~/Dev/skills/global/{standup,hotwash}/SKILL.md
  ↓ harness/wire render
~/.config/opencode/commands/<command>.md

~/Dev/skills/engineering/{codebase-map,codebase-grill}/SKILL.md
  ↓ harness/wire render with --project
<repo>/.opencode/commands/<command>.md

~/Dev/skills/commands/<command>.md      ← source (this repo)
  ↑ symlink
~/.claude/commands/<command>.md         ← boot command, available everywhere

~/Dev/skills/hooks/<hook>.sh           ← source (this repo)
  ↑ symlink, plus an entry in ~/.claude/settings.json
~/.claude/hooks/<hook>.sh              ← runs on every matching tool call

~/Dev/skills/harness/opencode/plugins/main-branch-guard.ts
  ↑ one-hop managed symlink
~/.config/opencode/plugins/main-branch-guard.ts
  ↓ translates native bash calls into the canonical shell policy
~/Dev/skills/hooks/main-branch-guard.sh

~/Dev/skills/global/unslop/VOICE.md    ← source (this repo)
  ↑ @-import, not a symlink
~/.claude/CLAUDE.md                    ← loaded every turn, in every project
```

**The one always-loaded file.** `global/unslop/VOICE.md` is the voice contract:
the scope clause plus the dozen rules that catch a model mid-reply. It is not a
skill, because a skill only enters context when the model calls it, and how
every message reads cannot depend on that decision. `~/.claude/CLAUDE.md`
imports it with a single `@` line, so this repo stays the source of truth. The
full 31-pattern catalogue stays in the `unslop` skill and loads on demand, which
keeps it off orchestration turns entirely.

A hook needs the settings entry as well as the link. The symlink alone does
nothing. `main-branch-guard.sh` is registered as a `PreToolUse` hook on `Bash`.
The sanitized baseline at `harness/claude-code/settings.json` carries the suite's
hook registrations, attribution policy, model defaults, and generic auto-mode
policy. The executor deep-merges that baseline into the installed settings. It
replaces only this repo's hook registrations and preserves unrelated local
preferences, including Herdr's vendor-managed registration.

`statusline-command.sh` and Herdr's agent-state files remain external. The
manifest reports them, and the executor never creates or replaces them.

Preview every Claude-managed global link, rendered agent, voice import, and
settings merge:

```sh
~/Dev/skills/harness/wire --harness claude-code
```

Dry-run is the default. Add `--apply` to create or repair managed links, render
agents and commands, and merge settings. The executor replaces stale managed
symlinks and generated files, but refuses foreign files or directories. It also
refuses to merge invalid JSON settings.

To link every engineering skill into a repo:

```sh
~/Dev/skills/harness/wire --harness claude-code --project /path/to/repo --apply
```

Repeat `--skill <name>` to select a subset. Project links remain one per skill,
and the executor reports real or foreign entries in `.claude/skills/` as
`unmanaged` without deleting them.

To wire a repo to the `engineering/` skills, run `project-setup` from that
repo's root. It calls `harness/wire`, creates per-skill symlinks under
`<repo>/.claude/skills/`, and gitignores them.

### OpenCode GPT smoke

Pi is deferred. The current MVP path is OpenCode `1.18.22` on
`openai/gpt-5.6-sol`:

```sh
~/Dev/skills/harness/wire --harness opencode --apply
~/Dev/skills/harness/opencode/openai
```

That global apply links the native branch guard plugin and renders the global
`/standup` and `/hotwash` commands. Render the two engineering commands into a
participating repository with:

```sh
~/Dev/skills/harness/wire --harness opencode --project /path/to/repo --apply
```

Repeat `--skill codebase-map` or `--skill codebase-grill` to narrow the
project command set. A global apply never installs either engineering command.

The launcher checks the CLI version, loads the provider-independent base, then
applies `profiles/openai.jsonc` for that process. It does not replace the global
OpenCode config. Quit and restart through the launcher after editing either
config file or the plugin; OpenCode loads them only at process startup.

For a non-interactive check:

```sh
~/Dev/skills/harness/opencode/openai run --agent build \
  "Reply with exactly OPENCODE_GPT_SMOKE_OK. Do not call tools."
```

The base loads `global/unslop/VOICE.md`, discovers canonical global skills,
allows vault access under `~/Dev/notes`, and denies dialogue-bound skills to the
native skill tool. Native commands provide the four dialogue-bound human entry
points: global `/standup` and `/hotwash`, plus project-scoped `/codebase-map`
and `/codebase-grill`. The profile keeps OpenCode's built-in `build`, `plan`,
`general`, and `explore` agents and adds the six canonical personas at mapped
GPT variants. Start directly in one with `openai --agent ennio`, or switch with
the native TUI agent selector. A command-bound primary agent still lasts only
for its command turn.

The native branch guard runs only for OpenCode `bash` calls. It passes the
command and native cwd to `hooks/main-branch-guard.sh`, which remains the sole
branch policy engine. A valid deny stops the tool with the shell hook's exact
reason. Adapter errors and malformed policy output are logged and fail open,
matching the shell hook's posture. Non-bash tools bypass the adapter.

Editing a linked `SKILL.md` here updates the skill everywhere immediately.
Editing a persona prompt, persona metadata, or a `SKILL.md` used by a rendered
command requires rerunning the matching harness manifest.

## Invocation taxonomy

Every **engineering** skill is one of two kinds:

- **Orchestrator**: a thin front door a human runs. Composes disciplines by
  prose. **Model-invocable by default** (the `*` rows in §Router, which is where
  that roster is kept rather than duplicated here): a sub-agent reaches only
  skills the model may invoke, so guarding one hides the method from the very
  agent spawned to run it.
  Add `disable-model-invocation: true` only when the skill is **dialogue-bound**:
  it advances by asking the human numbered questions, so a sub-agent cannot run
  it to completion. The guard buys zero per-turn cost; a description is ~60–90
  tokens per turn, in wired repos only.
- **Discipline**: the reusable method, `user-invocable: false` (model-only,
  hidden from `/`). Rich trigger description.

The one rule (an invariant; see `CLAUDE.md`): an orchestrator composes
disciplines, **never** another orchestrator. Shared behavior lives once, in a
discipline.

The `global/` primitives (`map`/`grill`/`handoff`/`skill-setup`) are a
deliberate exception: they stay **model-invoked front doors** so they trigger on
natural language ("grill this", "map it out"). `map` and `grill` are the
*general* front doors, thin over the `diverge` / `converge` disciplines that any
specialized front door (`codebase-map`, `codebase-grill`, and future
`<domain>-grill|map`) composes directly.

A discipline lives at the lowest layer that covers all its consumers:
`converge`/`diverge` in `global/` because global front doors compose them;
`review` in `engineering/` because only engineering does.

Which name a bare family word takes: the **general user entry** when one exists
(`map`, `grill`), otherwise the **discipline** (`review` has no general front
door, so it keeps the bare name).

## Naming

`<qualifier>-<primitive>`. The bare primitive is the general case; a qualifier
specializes it (`grill` → `codebase-grill`; `review` → `codebase-review`,
`pr-review`). Qualify to dodge built-ins (`/code-review`, `/review`).

## Tiering

Single-turn disciplines pin `model`/`effort` in Claude-native **skill**
frontmatter (resets next turn, which is correct for one-shot methods).
Multi-turn/agentic work tiers via the **agent**, which holds the tier across the
loop. The semantic assignments and each harness/provider target live in
[`harness/models.json`](./harness/models.json). Claude's ceiling is Opus 5
xhigh (Fable high while the subscription allows). Claude frontmatter pins exact
model ids: canonical skill frontmatter carries skill pins, and rendered agent
frontmatter carries persona pins. Never use a bare alias like `sonnet`, and
never append a date suffix. The Claude session default in the settings baseline
resolves through the same model map.

A pin's **lifetime** is the deciding factor, not the skill's size: a skill
override resets at the next user prompt, so any loop that iterates with the
human has to tier through an agent instead. Build is one such loop;
define-and-approve is another.

Agent tiers (default → escalation when a turn is genuinely stuck):

| Agent     | Role               | Default       | Escalation   |
| --------- | ------------------ | ------------- | ------------ |
| `@ennio`  | orchestrate        | Opus 5 high   | Opus 5 xhigh |
| `@bit`    | implement/refactor | Opus 5 medium | Opus 5 high  |
| `@vitruv` | spec/issues        | Opus 5 high   | Opus 5 xhigh |
| `@tux`    | git                | Sonnet 5 med  | Opus 5 high  |
| `@linn`   | docs / vault       | Sonnet 5 med  | Opus 5 high  |
| `@radar`  | state / briefings  | Opus 5 medium | Opus 5 high  |

Single-turn skills self-tier: `codebase-map`, `codebase-grill`, `refactor`,
`adr`, `codebase-review`, `pr-review` = Opus 5 high; `audit` = Opus 5 xhigh;
`aar` = Opus 5 medium. Multi-turn skills carry **no** skill pin and tier through
the agent that owns them: `prototype` and `implement` run as **@bit**, `spec`
and `issues` as **@vitruv**, `update-docs` as **@linn**; the `review`,
`design`, and `unslop` disciplines inherit the tier of the skill that composes
them.

Every agent signs its tier. Claude Code uses `— ran: <model-id> · effort:
<tier>`; OpenCode uses `variant` in place of `effort`. The agent reports the
runtime value when the harness exposes it and labels a configured value rather
than presenting it as observed fact. Any escalation includes its reason.

## Commands

For Claude Code, `commands/` holds one boot command per agent: a prompt template
that makes the main session **embody** that agent (you ARE it; not spawned as a
sub-agent). Each file symlinks to `~/.claude/commands/<name>.md`, so
`/enn`, `/bit`, `/vitruv`, `/tux`, `/linn`, `/radar` resolve in any repo. `/enn`
boots the orchestrator / command-post companion. **Bare** `/enn` orients across
hq then stands by; `/enn <task>` orients only at what the task names and explores
lazily, never reading hq to re-derive a scope it was handed. The other five boot
a focused single-worker session. `project-setup` links the commands and renders
the agents through the manifest executor.

OpenCode does not install those boot templates. In OpenCode `1.18.22`, a
command-bound agent and model apply for one command turn and do not change the
TUI's selected agent. Choose a durable persona with `openai --agent <name>` at
startup or with the native TUI selector.

OpenCode instead renders four command adapters from canonical skill sources.
Global `/standup` and `/hotwash` bind Radar for their command turn.
Project-scoped `/codebase-map` and `/codebase-grill` carry no agent binding.
All four pass `$ARGUMENTS`, resolve their OpenAI model and variant through
`harness/models.json`, and remain denied to the native skill tool.

## Router

The dispatch map of every user-reachable skill. **Invariant (see `CLAUDE.md`):
when you add, rename, remove, or re-scope a skill, update this table in the same
commit.** A router that lies is the named failure mode of this repo.

| Skill                  | Layer       | Kind          | What it does                                                           |
| ---------------------- | ----------- | ------------- | --------------------------------------------------------------------- |
| `map`                  | global      | model-invoked | General front door to divergence: compose `diverge` on a raw idea.     |
| `grill`                | global      | model-invoked | General front door to convergence: compose `converge` on a subject.    |
| `diverge`              | global      | discipline    | Shared divergence method + map artifact; composed, not run directly.   |
| `converge`             | global      | discipline    | Shared convergence method + grill artifact; composed, not run directly.|
| `handoff`              | global      | model-invoked | Capture working state for a zero-context successor.                    |
| `skill-setup`          | global      | model-invoked | Author/prune skills (taxonomy, naming, failure modes).                 |
| `project-setup`        | global      | user-invoked* | Wire a repo to consume `engineering/` skills; scaffold its vault HEAD. |
| `standup`              | global      | user-invoked  | Log-in briefing via `@radar`; bare = every project, arg = only that.   |
| `hotwash`              | global      | user-invoked  | Log-out debrief via `@radar`; bare seals the day, arg debriefs only it.|
| `branch-prune`         | global      | user-invoked* | Delete landed branches via `@tux`; refuses on dirty tree/PR/worktree.  |
| `unslop`               | global      | model-invoked | Cut AI tells from user-facing prose; catalogue behind `VOICE.md`.      |
| `codebase-map`         | engineering | orchestrator  | Load repo context, then compose `diverge` with the code as the lens.   |
| `codebase-grill`       | engineering | orchestrator  | Load repo context, then compose `converge` against the live code.      |
| `prototype`            | engineering | orchestrator* | Build a throwaway prototype to learn; runs as @bit, files the note.    |
| `aar`                  | engineering | orchestrator* | Synthesize what the prototype taught: reliable vs discard.            |
| `audit`                | engineering | orchestrator* | Bucket the prototype→reliable assurance gap (analysis only).           |
| `spec`                 | engineering | orchestrator* | Synthesize a spec from an agreed understanding; runs as @vitruv.         |
| `issues`               | engineering | orchestrator* | Cut an approved spec into slice issues; runs as @vitruv, stops at those. |
| `implement`            | engineering | orchestrator* | Build one reliable slice red→green; runs as @bit, commits via @tux.    |
| `refactor`             | engineering | orchestrator* | Diagnose a refactor → refactor-diagnosis; build via `implement`.       |
| `adr`                  | engineering | orchestrator* | Record a qualifying architecture decision in-repo; keep the index.     |
| `codebase-review`      | engineering | orchestrator* | Compose `review` against the local working diff.                       |
| `pr-review`            | engineering | orchestrator* | Compose `review` against a GitHub PR.                                  |
| `review`               | engineering | discipline    | Shared code-review method; composed by the two above, never direct.    |
| `design`               | engineering | discipline    | Design vocabulary (seam, depth, adapter) + smell baseline; composed.   |
| `update-docs`          | engineering | orchestrator* | Reconcile docs with the implementation; runs as @linn.                 |

`*` = also **model-invocable** (no `disable-model-invocation`), so a delegated
sub-agent can invoke it directly instead of only a human at the `/` prompt. The
unstarred `codebase-map` / `codebase-grill` / `standup` / `hotwash` stay
human-only because each advances by asking the human questions; see §Invocation
taxonomy.

Reach is scoped **per repo**, not by this flag: `engineering/` skills exist only
where `project-setup` symlinked them (`<repo>/.claude/skills/`), and that skill
asks which subset to link. A repo with no engineering skills linked, say a
writing vault, never sees `codebase-map` in context whether it is guarded or
not.

## Vault

Skills are stateless. They persist artifacts to `~/Dev/notes` per that vault's
`_saving.md` (path, frontmatter, HEAD update, wikilinks), the single filing
spec, never duplicated into a skill. `cycle` and `SDP` are retired vocabulary;
do not emit them.

## Deferred (not yet built)

- Further specialized `<domain>-grill` / `<domain>-map` front doors (e.g. a
  `positions-grill` hunting cohesive market positioning). The seam is proven:
  `codebase-grill` and `codebase-map` are the first pair; each new one is
  `{preload context} + {domain lens} → compose converge|diverge`.
