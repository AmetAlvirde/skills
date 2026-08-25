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

export type DaylogDiagnostic = {
  kind: "malformed-event" | "policy-execution" | "policy-response"
  message: string
  error?: unknown
}

type Dependencies = {
  runPolicy?: (request: PolicyRunRequest) => string | Promise<string>
  diagnose?: (input: PluginInput, diagnostic: DaylogDiagnostic) => void | Promise<void>
  consoleWarn?: (...values: unknown[]) => void
  hookPath?: string
}

type NativeRecord = Record<string, unknown>

function canonicalHookPath(): string {
  const source = realpathSync(fileURLToPath(import.meta.url))
  return resolve(dirname(source), "../../../hooks/daylog-trigger.sh")
}

function runCanonicalPolicy({ hookPath, cwd, input }: PolicyRunRequest): string {
  const result = spawnSync(hookPath, [], { cwd, input, encoding: "utf8", env: process.env })
  if (result.error) throw result.error
  if (result.status !== 0) {
    throw new Error(`policy exited with status ${result.status ?? "unknown"}`)
  }
  return result.stdout
}

function isRecord(value: unknown): value is NativeRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}

function nonemptyString(value: unknown): value is string {
  return typeof value === "string" && value.length > 0
}

function safeConsoleWarning(consoleWarn: (...values: unknown[]) => void, ...values: unknown[]): void {
  try {
    consoleWarn(...values)
  } catch {
    // Logging cannot turn this recording adapter into a session failure.
  }
}

async function logDiagnostic(input: PluginInput, diagnostic: DaylogDiagnostic): Promise<void> {
  const result = await input.client.app.log({
    body: {
      service: "daylog-trigger",
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

function normalizedTool(tool: string): "Edit" | "Write" | "Bash" | undefined {
  switch (tool) {
    case "edit":
    case "apply_patch":
      return "Edit"
    case "write":
      return "Write"
    case "bash":
      return "Bash"
    default:
      return undefined
  }
}

function validCompletedState(state: NativeRecord): boolean {
  if (!isRecord(state.input)) return false
  if (typeof state.output !== "string" || typeof state.title !== "string") return false
  if (!isRecord(state.metadata) || !isRecord(state.time)) return false
  return typeof state.time.start === "number" && typeof state.time.end === "number"
}

export function createDaylogTriggerPlugin(dependencies: Dependencies = {}): Plugin {
  const runPolicy = dependencies.runPolicy ?? runCanonicalPolicy
  const diagnose = dependencies.diagnose ?? logDiagnostic
  const consoleWarn = dependencies.consoleWarn ?? console.warn

  return async (pluginInput) => {
    const diagnoseSafely = async (diagnostic: DaylogDiagnostic): Promise<void> => {
      try {
        await diagnose(pluginInput, diagnostic)
      } catch (error) {
        safeConsoleWarning(
          consoleWarn,
          `[daylog-trigger] ${diagnostic.message}; diagnostics failed`,
          error,
        )
      }
    }

    const invokePolicy = async (cwd: string, payload: NativeRecord): Promise<void> => {
      let input: string
      try {
        input = JSON.stringify(payload)
      } catch (error) {
        await diagnoseSafely({
          kind: "malformed-event",
          message: "native event context could not be serialized; skipping daylog policy",
          error,
        })
        return
      }

      let stdout: string
      try {
        stdout = await runPolicy({
          hookPath: dependencies.hookPath ?? canonicalHookPath(),
          cwd,
          input,
        })
      } catch (error) {
        await diagnoseSafely({
          kind: "policy-execution",
          message: "canonical daylog policy execution failed; continuing session",
          error,
        })
        return
      }

      if (stdout.length === 0) return

      let error: unknown
      try {
        JSON.parse(stdout)
      } catch (parseError) {
        error = parseError
      }
      await diagnoseSafely({
        kind: "policy-response",
        message: error === undefined
          ? "canonical daylog policy returned unexpected output; continuing session"
          : "canonical daylog policy returned malformed output; continuing session",
        error,
      })
    }

    const malformed = async (message: string): Promise<void> => {
      await diagnoseSafely({ kind: "malformed-event", message })
    }

    return {
      event: async (input) => {
        try {
          const event: unknown = input.event
          if (!isRecord(event) || typeof event.type !== "string") {
            await malformed("native event envelope or type is malformed")
            return
          }

          if (event.type === "session.created") {
            if (!isRecord(event.properties) || !isRecord(event.properties.info)) {
              await malformed("session.created info is malformed")
              return
            }
            const { id, directory } = event.properties.info
            if (!nonemptyString(id) || !nonemptyString(directory)) {
              await malformed("session.created id and directory must be nonempty strings")
              return
            }
            await invokePolicy(directory, {
              hook_event_name: "SessionStart",
              session_id: id,
              cwd: directory,
            })
            return
          }

          if (event.type !== "message.part.updated") return
          if (!isRecord(event.properties) || !isRecord(event.properties.part)) {
            await malformed("message.part.updated part is malformed")
            return
          }

          const part = event.properties.part
          if (part.type !== "tool") return
          if (!nonemptyString(part.sessionID) || !nonemptyString(part.tool) || !isRecord(part.state)) {
            await malformed("tool completion identity or state is malformed")
            return
          }

          const status = part.state.status
          if (status === "error" || status === "pending" || status === "running") return
          if (status !== "completed") {
            await malformed("tool completion status is unknown")
            return
          }

          const toolName = normalizedTool(part.tool)
          if (toolName === undefined) return
          if (!validCompletedState(part.state)) {
            await malformed("completed tool state is malformed")
            return
          }

          const toolInput = part.state.input as NativeRecord
          if (
            Object.prototype.hasOwnProperty.call(toolInput, "workdir")
            && !nonemptyString(toolInput.workdir)
          ) {
            await malformed("explicit tool workdir must be a nonempty string")
            return
          }
          if (toolName === "Bash" && typeof toolInput.command !== "string") {
            await malformed("completed bash command must be a string")
            return
          }

          const cwd = typeof toolInput.workdir === "string" ? toolInput.workdir : pluginInput.directory
          if (!nonemptyString(cwd)) {
            await malformed("effective tool cwd must be a nonempty string")
            return
          }

          await invokePolicy(cwd, {
            hook_event_name: "PostToolUse",
            session_id: part.sessionID,
            tool_name: toolName,
            cwd,
            tool_input: toolInput,
          })
        } catch (error) {
          await diagnoseSafely({
            kind: "malformed-event",
            message: "unexpected native event adapter failure; continuing session",
            error,
          })
        }
      },
    }
  }
}

const DaylogTriggerPlugin: Plugin = createDaylogTriggerPlugin()

export default DaylogTriggerPlugin
