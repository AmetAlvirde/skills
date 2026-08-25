import type { Plugin, PluginInput } from "@opencode-ai/plugin"
import { spawnSync } from "node:child_process"
import { realpathSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

export type PolicyRunRequest = {
  hookPath: string
  cwd: string
  input: string
}

export type GuardDiagnostic = {
  kind: "malformed-args" | "policy-execution" | "policy-response"
  message: string
  error?: unknown
}

type Dependencies = {
  runPolicy?: (request: PolicyRunRequest) => string | Promise<string>
  diagnose?: (input: PluginInput, diagnostic: GuardDiagnostic) => void | Promise<void>
  consoleWarn?: (...values: unknown[]) => void
  hookPath?: string
}

function canonicalHookPath(): string {
  const source = realpathSync(fileURLToPath(import.meta.url))
  return resolve(dirname(source), "../../../hooks/main-branch-guard.sh")
}

function runCanonicalPolicy({ hookPath, cwd, input }: PolicyRunRequest): string {
  const result = spawnSync(hookPath, [], {
    cwd,
    input,
    encoding: "utf8",
  })
  if (result.error) throw result.error
  if (result.status !== 0) {
    throw new Error(`policy exited with status ${result.status ?? "unknown"}`)
  }
  return result.stdout
}

function safeConsoleWarning(consoleWarn: (...values: unknown[]) => void, ...values: unknown[]): void {
  try {
    consoleWarn(...values)
  } catch {
    // Diagnostics must not turn a fail-open adapter into a tool veto.
  }
}

async function logDiagnostic(input: PluginInput, diagnostic: GuardDiagnostic): Promise<void> {
  const result = await input.client.app.log({
    body: {
      service: "main-branch-guard",
      level: "warn",
      message: diagnostic.message,
      extra: {
        kind: diagnostic.kind,
        error: diagnostic.error instanceof Error
          ? diagnostic.error.message
          : diagnostic.error === undefined ? undefined : String(diagnostic.error),
      },
    },
  })
  if (result.error) throw result.error
}

function denyReason(stdout: string): string | undefined {
  const parsed: unknown = JSON.parse(stdout)
  if (typeof parsed !== "object" || parsed === null) return undefined
  const output = (parsed as { hookSpecificOutput?: unknown }).hookSpecificOutput
  if (typeof output !== "object" || output === null) return undefined
  const decision = output as Record<string, unknown>
  if (
    decision.hookEventName !== "PreToolUse"
    || decision.permissionDecision !== "deny"
    || typeof decision.permissionDecisionReason !== "string"
  ) return undefined
  return decision.permissionDecisionReason
}

export function createMainBranchGuardPlugin(dependencies: Dependencies = {}): Plugin {
  const runPolicy = dependencies.runPolicy ?? runCanonicalPolicy
  const diagnose = dependencies.diagnose ?? logDiagnostic
  const consoleWarn = dependencies.consoleWarn ?? console.warn

  return async (pluginInput) => {
    const diagnoseSafely = async (diagnostic: GuardDiagnostic): Promise<void> => {
      try {
        await diagnose(pluginInput, diagnostic)
      } catch (error) {
        safeConsoleWarning(
          consoleWarn,
          `[main-branch-guard] ${diagnostic.message}; diagnostics failed`,
          error,
        )
      }
    }

    return {
      "tool.execute.before": async (input, output) => {
        if (input.tool !== "bash") return

        const args: unknown = output.args
        if (typeof args !== "object" || args === null || Array.isArray(args)) {
          await diagnoseSafely({ kind: "malformed-args", message: "bash tool args are not an object" })
          return
        }

        const nativeArgs = args as Record<string, unknown>
        if (typeof nativeArgs.command !== "string") {
          await diagnoseSafely({ kind: "malformed-args", message: "bash tool command is not a string" })
          return
        }
        if (
          Object.prototype.hasOwnProperty.call(nativeArgs, "workdir")
          && (typeof nativeArgs.workdir !== "string" || nativeArgs.workdir.length === 0)
        ) {
          await diagnoseSafely({ kind: "malformed-args", message: "bash tool workdir is not a nonempty string" })
          return
        }

        const cwd = typeof nativeArgs.workdir === "string" ? nativeArgs.workdir : pluginInput.directory
        const payload = JSON.stringify({
          hook_event_name: "PreToolUse",
          session_id: input.sessionID,
          tool_name: "Bash",
          cwd,
          tool_input: { command: nativeArgs.command },
        })

        let stdout: string
        try {
          stdout = await runPolicy({
            hookPath: dependencies.hookPath ?? canonicalHookPath(),
            cwd,
            input: payload,
          })
        } catch (error) {
          await diagnoseSafely({
            kind: "policy-execution",
            message: "canonical policy execution failed; allowing tool call",
            error,
          })
          return
        }

        if (stdout.length === 0) return

        let reason: string | undefined
        try {
          reason = denyReason(stdout)
        } catch (error) {
          await diagnoseSafely({
            kind: "policy-response",
            message: "canonical policy returned malformed JSON; allowing tool call",
            error,
          })
          return
        }
        if (reason === undefined) {
          await diagnoseSafely({
            kind: "policy-response",
            message: "canonical policy returned a non-deny response; allowing tool call",
          })
          return
        }

        // Keep the valid deny outside every fail-open catch.
        throw new Error(reason)
      },
    }
  }
}

const MainBranchGuardPlugin: Plugin = createMainBranchGuardPlugin()

export default MainBranchGuardPlugin
