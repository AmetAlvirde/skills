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
| Human-only skill entry | native (`disable-model-invocation`) | adapted (command plus skill deny, planned) | unsupported (deferred) |
| Skill-triggered tier switch | native | degraded (active agent tier is inherited) | unsupported (deferred) |
| Pre-tool veto | native hook | adapted (plugin throw, planned) | unsupported (veto spike deferred) |
| Terminal session close | native `SessionEnd` | unsupported (no terminal event) | unsupported (deferred) |
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
`skill` load passed through the OpenAI profile on 2026-08-24. The CLI and
`@opencode-ai/plugin` SDK are both pinned to `1.18.22`.

## Required outcomes

Every active harness must provide these outcomes or mark the gap as degraded or
unsupported in the table above.

1. Global skills are discoverable in every repository. Engineering skills are
   discoverable only in repositories that opted into each skill.
2. Natural-language requests can load model-invoked skills. Dialogue-bound
   skills remain human entry points and cannot be delegated as model-invoked
   skills.
3. Canonical behavior comes from this repository at invocation time. A harness
   must not install editable copies of skill or persona bodies.
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

Claude Code reads these fields from canonical Markdown frontmatter. They remain
in place while Claude Code is an active harness:

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

Every persona's closing tier signature reports `model-id` and `effort`. A
harness may use its native variant name in place of effort. The model is runtime
fact only when the harness exposes it. A configured value is declared state and
must not be presented as observed runtime state.

OpenCode cannot switch model or variant during the turn in which its native
skill tool loads a skill. Explicit commands may pin a target. Natural-language
skill invocation inherits the active agent tier. This is a measured degradation,
not equivalent per-skill tiering. Do not replace the native skill tool until
live use shows that degradation is unacceptable.

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

The persona refactor will extract one portable prompt per persona and keep
harness metadata separate. `harness/wire` must render each native runtime agent
from that prompt and its harness metadata. Rendered files are installed output,
not editable sources. Until that refactor lands, canonical `agents/*.md` files
stay intact.

An OpenCode command binder may select a native primary agent and pass
`$ARGUMENTS`, but the selection applies only to that command turn. The live
TUI's selected-agent state does not change, so the next user turn returns to the
previous agent. Persona boot must select the primary agent at startup, use the
native TUI switch, or add a tested session-state mechanism. Prompt text carried
in conversation history is not a model or permission switch.

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

Malformed adapter output fails open, matching the shell policy. Adapter load
failure must be visible in tests and startup diagnostics.

### Daylog

`hooks/daylog-trigger.sh` remains the MVP policy engine. An adapter normalizes
successful authoring tools, including OpenCode `apply_patch`, and maps session
creation where useful. It never throws.

OpenCode has no event equivalent to terminal `SessionEnd`. The MVP contract
assigns lazy minting and activity to the plugin and authoritative
closure to `/hotwash`. The user approved that contract on 2026-08-24. Repeating
idle events and process-exit launchers must not be described as terminal-close
parity.

## Wiring and external state

`harness/wire` reads `harness/*/wiring.json`. Manifests declare links, imports,
JSON merges, project-scoped links, external integrations, and deferred config.
Harness-specific installers are not allowed.

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
