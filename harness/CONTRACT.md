# Harness contract

This repository owns behavior once. `global/`, `engineering/`, `agents/`,
`commands/`, and `hooks/` are canonical. A directory under `harness/` may own
discovery, native metadata, permissions, protocol adapters, configuration,
wiring, and tests. It may not carry a harness-specific copy of a canonical
skill or persona.

Generated runtime files are allowed when a harness needs a native format. They
must be rendered from canonical content and harness metadata, and must not
become a second editable source.

## Capability status

The status words describe the mechanism, not a claim that planned work already
exists:

- `native`: the harness exposes the capability directly.
- `adapted`: a tracked adapter maps the harness mechanism to this contract.
- `degraded`: the required outcome is only partly available. Acceptance must
  name the missing behavior.
- `unsupported`: the harness cannot provide the outcome, or this repository has
  deliberately deferred it.

The parenthetical text records implementation state or evidence still needed.

| Capability | Claude Code | OpenCode | Pi |
| --- | --- | --- | --- |
| Model-invoked skills | native | native | unsupported (deferred) |
| Human-only skill entry | native (`disable-model-invocation`) | adapted (rendered command plus native skill deny) | unsupported (deferred) |
| Skill-triggered tier switch | native | degraded (active agent tier is inherited) | unsupported (deferred) |
| Pre-tool veto | native hook | adapted (shell-backed plugin throw) | unsupported (veto spike deferred) |
| Terminal session close | native `SessionEnd` | unsupported (no terminal event) | unsupported (deferred) |
| Lazy daylog minting and activity | native hooks | adapted (successful native completion events) | unsupported (deferred) |
| Persistent persona boot | native command | adapted (startup agent selection; command binding lasts one turn) | unsupported (deferred) |
| Voice loading | native global import | adapted (config `instructions`, verified) | unsupported (deferred) |
| Global and project skill scopes | native | native | unsupported (deferred) |
| Positional command arguments | native `$ARGUMENTS` | native `$ARGUMENTS` | unsupported (deferred) |
| Native subagents | native | native | unsupported (deferred) |

OpenCode facts in this table were verified against CLI `1.18.22`. Re-test them
when the supported CLI version changes. OpenCode recognizes Agent Skill
`name`, `description`, `license`, `compatibility`, and `metadata` fields. It
ignores Claude Code's invocation and tier fields.

An authenticated `openai/gpt-5.6-sol` smoke and an explicit model-invoked
`skill` load passed through the OpenAI profile on 2026-08-24. The native branch
guard adapter also passed a real refusal smoke in a throwaway repository. The
daylog adapter passed a real smoke under an isolated HOME and notes vault: a
successful read-only Bash call left activity unminted, while a successful
authoring call minted the daylog and recorded its native session ID. The CLI and
`@opencode-ai/plugin` SDK are both pinned to `1.18.22`.

## Required outcomes

Every active harness must provide these outcomes or mark the gap as degraded or
unsupported in the table above.

1. Global skills are discoverable in every repository. Engineering skills are
   discoverable only in repositories that opted into each skill.
2. Natural-language requests can load model-invoked skills. Dialogue-bound
   skills remain human entry points and cannot be delegated as model-invoked
   skills.
3. Canonical behavior has one editable source in this repository. A harness may
   link it or render managed native output, but must not install a second
   editable copy of a skill or persona body.
4. Model and reasoning settings resolve through `models.json`. Native
   projections must match it.
5. Personas keep their role boundaries through native permissions or an
   adapter. A model prompt is not a permission boundary.
6. The voice contract in `global/unslop/VOICE.md` loads even when a project has
   its own instruction file.
7. Hook adapters preserve the policy engine's working directory, fail-open or
   veto posture, and refusal reason.
8. Wiring is idempotent, uses one-hop links where the harness supports them,
   reports unmanaged paths, and leaves vendor-owned integrations alone.

## Claude-native metadata

Claude Code reads these fields from canonical skill frontmatter, command
frontmatter, or rendered agent frontmatter. They remain in those native
projections while Claude Code is an active harness:

| Field | Contract meaning |
| --- | --- |
| `model` | Exact Claude Code model pin for the current turn or persona. |
| `effort` | Claude Code reasoning level paired with `model`. |
| `user-invocable: false` | Discipline hidden from human command discovery. |
| `disable-model-invocation: true` | Human-only entry that the model may not load as a skill. |
| `color` | Claude Code's native agent display metadata. |
| `argument-hint` | Claude Code's command argument hint. It has no portable effect. |

Other harnesses must implement the contract meaning through their native
configuration. They must not pretend Claude fields apply automatically.

## Tier policy

`models.json` maps each semantic assignment to exact harness and provider
targets. Claude skill frontmatter remains the Claude Code projection and must
match the corresponding `skillPins` entry. OpenCode uses provider-qualified
model IDs and variants in its active profile and agent configuration.

A tier has a lifetime:

- A single-turn skill pin applies to the turn in which the skill loads.
- A persona default persists for that persona's run.
- An escalation is temporary and must be reported in the tier sign line.
- A skill retry ends the default turn and starts one fresh command turn at the
  configured retry target. It carries the first pass's reason and runs at most
  once; a skill never changes its own model or effort in flight.

Every persona's closing tier signature reports `model-id` and `effort`. A
harness may use its native variant name in place of effort. The model is runtime
fact only when the harness exposes it. A configured value is declared state and
must not be presented as observed runtime state.

OpenCode cannot switch model or variant during the turn in which its native
skill tool loads a skill. Explicit commands may pin a target. Natural-language
skill invocation inherits the active agent tier. This is a measured degradation,
not equivalent per-skill tiering. Do not replace the native skill tool until
live use shows that degradation is unacceptable.

`skillPins.<name>.default` is the native skill's fixed tier.
`skillPins.<name>.retry` is valid only when both harnesses expose an explicit
retry command that consumes it. The command copies the canonical skill body
without invoking native skill loading, which would restore the default pin.

`harness/opencode/openai` is the tested profile selector. It loads the base with
`OPENCODE_CONFIG` and injects the OpenAI profile through
`OPENCODE_CONFIG_CONTENT`, then starts a new OpenCode process. The resolved
config and an authenticated GPT call proved the selection. OpenCode reads config
only at startup, so changing either file requires a restart.

## Personas and commands

Harness metadata must not leak contradictory model, effort, or permission text
into another provider's prompt. OpenCode `1.18.22` substitutes `{file:...}`
verbatim, including YAML frontmatter. A native OpenCode agent Markdown file
strips its own frontmatter before using the body as the prompt. Pointing
OpenCode config at canonical whole `agents/*.md` files is therefore rejected.

Claude Code `2.1.243` also leaves an `@/path/to/persona-body.md` reference in an
agent body unexpanded. A control agent received the same instruction when it
was inline, which rules out agent discovery or invocation as the cause. Claude
agent definitions cannot import a shared prompt body.

Each `agents/*.md` file is one portable persona prompt. Shared descriptions live
in `agents/manifest.json`; native fields and permission boundaries live under
the matching harness. `harness/wire` resolves the model target through
`models.json` and renders each runtime agent. It replaces only an old managed
symlink or a file carrying its generated marker. Rendered files are installed
output, not editable sources.

OpenCode exposes exactly four dialogue-bound skill adapters. `/standup` and
`/hotwash` are global. `/codebase-map` and `/codebase-grill` are project-scoped.
The same four skills remain denied to OpenCode's native skill tool and enter
through commands instead. It also exposes project-scoped
`/codebase-review-retry`, `/pr-review-retry`, and `/refactor-retry`; Claude Code
renders the same three retry commands.

Canonical descriptions and bodies come from each adapter's `SKILL.md`.
Each harness's command catalog owns only adaptation metadata, source pointers,
and semantic model references. `harness/wire` renders the native files with
`$ARGUMENTS` and the model tier resolved through `models.json`. `/standup` and
`/hotwash` bind Radar for that command turn. The five project commands do not
bind a persona.

In OpenCode `1.18.22`, a command's primary agent and model selection apply only
to that command turn. The live TUI's selected-agent state does not change, so
the next user turn returns to the previous selection. Durable persona state
requires launcher startup selection or the native TUI selector. Prompt text in
conversation history is not a model or permission switch. The six
`commands/*.md` persona boot templates remain Claude-only and must not be
installed or described as OpenCode commands. This adapter adds no hook or
plugin.

## Policy protocol

The permanent cross-harness protocol is a normalized request and response. The
MVP adapters may translate native events into Claude-shaped JSON to preserve the
tested shell policy engines. Claude's payload is an implementation bridge, not
the contract.

Normalized request:

```json
{
  "version": 1,
  "policy": "main-branch-guard",
  "event": "tool.before",
  "session": { "id": "session-id" },
  "tool": {
    "name": "shell",
    "input": { "command": "git commit -m example" },
    "workdir": "/absolute/repository/path",
    "success": null
  },
  "reason": null
}
```

Normalized response:

```json
{
  "version": 1,
  "decision": "deny",
  "reason": "Refusing: this would commit straight to the default branch."
}
```

`decision` is `allow` or `deny`. `reason` is required for deny. Recording
policies such as `daylog-trigger` always return allow and never stop the native
tool.

### Branch floor

`hooks/main-branch-guard.sh` remains the MVP policy engine. A native adapter:

1. runs only before shell execution;
2. preserves the native call's workdir when launching the shell script;
3. supplies the command in the tested Claude payload shape;
4. parses the script's deny JSON; and
5. stops the native tool with the returned reason.

`harness/opencode/plugins/main-branch-guard.ts` implements that adapter for
OpenCode's native `bash` tool. It sends the session ID, command, and effective
cwd in the Claude-shaped bridge payload. The shell process runs in
`output.args.workdir` when the call supplies one, otherwise in the plugin's
`directory`.

Empty output allows the tool. A valid deny response throws an `Error` whose
message is the shell policy's exact refusal reason. Malformed arguments,
malformed nonempty output, shell execution failures, and diagnostic failures
all fail open. Adapter failures go to OpenCode's application log, with a guarded
console warning if logging itself fails.

### Daylog

`hooks/daylog-trigger.sh` remains the MVP policy engine. An adapter normalizes
OpenCode's native event stream into the Claude-shaped payload that engine already
tests. `session.created` becomes `SessionStart`, preserving the native session ID
and directory without minting a daylog. A resumed session has no matching native
event; its first successful authoring completion reaches `PostToolUse`, and the
shell policy's existing mid-session fallback opens its state lazily.

Only completed `edit`, `write`, `apply_patch`, and `bash` tool parts reach the
policy. The adapter maps them to `Edit`, `Write`, `Edit`, and `Bash`
respectively, preserving file, patch, or command input. It forwards every
successful Bash completion so the canonical shell policy, not TypeScript,
decides whether the command is authoring. Error, pending, and running states,
unknown tools, read tools, and unrelated events record nothing.

The policy process runs in the tool's nonempty `workdir` when supplied and the
plugin directory otherwise; the same effective cwd appears in the payload.
Malformed events, invalid workdirs, shell failures, and unexpected or malformed
policy output are diagnosed through OpenCode logging and fail open. Diagnostic
failure falls back to a guarded console warning. The adapter never throws.

OpenCode has no event equivalent to terminal `SessionEnd`. The MVP contract
assigns lazy minting and activity to the plugin and authoritative
closure to `/hotwash`. The user approved that contract on 2026-08-24. Repeating
idle events and process-exit launchers must not be described as terminal-close
parity.

## Wiring and external state

`harness/wire` reads `harness/*/wiring.json`. Manifests declare links, imports,
JSON merges, native agent and command renders, project-scoped links, external
integrations, and deferred config. Harness-specific installers are not allowed.

The OpenCode command render declaration points to
`harness/opencode/commands.json` and names separate global and project
destinations. A global apply renders only `standup` and `hotwash`. Engineering
adapters render under `<repo>/.opencode/commands/` only when `--project` is
present, and `--skill` may narrow that set. This preserves the Router's project
reach. Command renders support dry-run, carry a managed marker, replace only
managed output, refuse foreign files and symlinks, and report unchanged output
as idempotent.

Both active harness manifests expose canonical `engineering/` skills through
selectable project links. Claude Code links them under
`<repo>/.claude/skills/`; OpenCode links them under
`<repo>/.opencode/skills/`. Every link targets `engineering/<skill>` directly.
The same `--skill` selectors can be repeated for each harness. Dry-run,
idempotence, unmanaged scanning, and foreign-path refusal are shared executor
behavior.

The OpenCode manifest links only `harness/opencode/plugins/main-branch-guard.ts`
and `harness/opencode/plugins/daylog-trigger.ts` into the global plugin
directory. Each one-hop link follows the same dry-run and idempotence rules as
the other managed links. Wiring refuses to replace foreign files or symlinks at
either path. Herdr's neighboring plugin remains vendor-managed.

`harness/claude-code/settings.json` owns the portable Claude settings baseline:
the suite's hook registrations, attribution policy, model defaults, and generic
auto-mode policy. `harness/wire` deep-merges it into the installed settings.
Baseline scalar values win, arrays retain distinct local additions, and keys the
baseline does not name remain untouched. The hook merge replaces registrations
for `main-branch-guard.sh` and `daylog-trigger.sh` by command name, then retains
every other hook registration.

Claude's `statusline-command.sh` is local and unversioned. Herdr owns
`herdr-agent-state.*` and its settings entries on every harness. Wiring reports
those paths but never creates, replaces, or edits them. The settings merge
preserves Herdr's native registration as unrelated local state.
