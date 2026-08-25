import { afterEach, describe, expect, test } from "bun:test"
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import type { Hooks, PluginInput } from "@opencode-ai/plugin"
import DaylogTriggerPlugin, {
  createDaylogTriggerPlugin,
  type DaylogDiagnostic,
  type PolicyRunRequest,
} from "../plugins/daylog-trigger"

const temporaryDirectories: string[] = []
const savedEnvironment = {
  DAYLOG_VAULT: process.env.DAYLOG_VAULT,
  DAYLOG_STATE: process.env.DAYLOG_STATE,
  DAYLOG_ACTIVITY: process.env.DAYLOG_ACTIVITY,
}

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true })
  }
  for (const [name, value] of Object.entries(savedEnvironment)) {
    if (value === undefined) delete process.env[name]
    else process.env[name] = value
  }
})

function pluginInput(directory = "/session/root"): PluginInput {
  return {
    directory,
    client: { app: { log: async () => ({ data: true }) } },
  } as unknown as PluginInput
}

async function eventHook(
  runPolicy: (request: PolicyRunRequest) => string | Promise<string>,
  diagnostics: DaylogDiagnostic[] = [],
  directory?: string,
): Promise<NonNullable<Hooks["event"]>> {
  const plugin = createDaylogTriggerPlugin({
    runPolicy,
    diagnose: async (_input, diagnostic) => diagnostics.push(diagnostic),
  })
  return (await plugin(pluginInput(directory))).event!
}

function sessionCreated(id = "session-123", directory = "/native/session") {
  return {
    event: {
      type: "session.created",
      properties: { info: { id, directory } },
    },
  } as Parameters<NonNullable<Hooks["event"]>>[0]
}

function completedTool(tool: string, input: Record<string, unknown>, sessionID = "session-123") {
  return {
    event: {
      type: "message.part.updated",
      properties: {
        part: {
          id: "part-1",
          messageID: "message-1",
          callID: "call-1",
          type: "tool",
          sessionID,
          tool,
          state: {
            status: "completed",
            input,
            output: "done",
            title: "done",
            metadata: {},
            time: { start: 1, end: 2 },
          },
        },
      },
    },
  } as Parameters<NonNullable<Hooks["event"]>>[0]
}

function isolatedPolicyEnvironment() {
  const root = mkdtempSync(join(tmpdir(), "daylog-trigger-plugin."))
  temporaryDirectories.push(root)
  const vault = join(root, "vault")
  const state = join(root, "state", "daylog-session.json")
  const activity = `${state}.activity`
  process.env.DAYLOG_VAULT = vault
  process.env.DAYLOG_STATE = state
  process.env.DAYLOG_ACTIVITY = activity
  return { root, vault, state, activity }
}

function mintedDaylog(vault: string): string | undefined {
  const hq = join(vault, "hq")
  if (!existsSync(hq)) return undefined
  const entry = new Bun.Glob("*-daylog.md").scanSync({ cwd: hq }).next().value
  return entry === undefined ? undefined : join(hq, entry)
}

describe("daylog trigger native event adapter", () => {
  test("session.created records SessionStart in its native directory without minting", async () => {
    const requests: PolicyRunRequest[] = []
    const hook = await eventHook((request) => (requests.push(request), ""))

    await hook(sessionCreated())

    expect(requests).toHaveLength(1)
    expect(requests[0]!.cwd).toBe("/native/session")
    expect(JSON.parse(requests[0]!.input)).toEqual({
      hook_event_name: "SessionStart",
      session_id: "session-123",
      cwd: "/native/session",
    })
  })

  test.each([
    ["edit", "Edit", { filePath: "/repo/a.ts", oldString: "old", newString: "new" }],
    ["write", "Write", { filePath: "/repo/b.ts", content: "new file" }],
    ["apply_patch", "Edit", { patchText: "*** Begin Patch\n*** End Patch" }],
  ])("translates successful %s completion to Claude %s and preserves context", async (native, claude, context) => {
    const requests: PolicyRunRequest[] = []
    const hook = await eventHook((request) => (requests.push(request), ""))

    await hook(completedTool(native, context))

    expect(requests).toHaveLength(1)
    expect(requests[0]!.cwd).toBe("/session/root")
    expect(JSON.parse(requests[0]!.input)).toEqual({
      hook_event_name: "PostToolUse",
      session_id: "session-123",
      tool_name: claude,
      cwd: "/session/root",
      tool_input: context,
    })
  })

  test("forwards every successful bash completion, including read-only commands", async () => {
    const requests: PolicyRunRequest[] = []
    const hook = await eventHook((request) => (requests.push(request), ""))

    await hook(completedTool("bash", { command: "git commit -m done" }))
    await hook(completedTool("bash", { command: "git status" }))

    expect(requests.map(({ input }) => JSON.parse(input).tool_input.command)).toEqual([
      "git commit -m done",
      "git status",
    ])
    expect(requests.every(({ input }) => JSON.parse(input).tool_name === "Bash")).toBe(true)
  })

  test("uses a nonempty explicit workdir for both process and payload cwd", async () => {
    const requests: PolicyRunRequest[] = []
    const hook = await eventHook((request) => (requests.push(request), ""))

    await hook(completedTool("edit", { filePath: "a.ts", workdir: "/tool/cwd" }))

    expect(requests[0]!.cwd).toBe("/tool/cwd")
    expect(JSON.parse(requests[0]!.input).cwd).toBe("/tool/cwd")
  })

  test("falls back to the plugin directory when workdir is absent", async () => {
    const requests: PolicyRunRequest[] = []
    const hook = await eventHook((request) => (requests.push(request), ""), [], "/fallback/cwd")

    await hook(completedTool("write", { filePath: "a.ts", content: "x" }))

    expect(requests[0]!.cwd).toBe("/fallback/cwd")
    expect(JSON.parse(requests[0]!.input).cwd).toBe("/fallback/cwd")
  })

  test("failed, pending, and running tools never invoke policy or record activity", async () => {
    let invoked = 0
    const hook = await eventHook(() => (invoked++, ""))
    for (const status of ["error", "pending", "running"]) {
      const input = completedTool("edit", { filePath: "a.ts" }) as unknown as { event: any }
      input.event.properties.part.state.status = status
      await expect(hook(input as Parameters<typeof hook>[0])).resolves.toBeUndefined()
    }
    expect(invoked).toBe(0)
  })

  test("unknown and read tools plus unrelated events are ignored", async () => {
    let invoked = 0
    const diagnostics: DaylogDiagnostic[] = []
    const hook = await eventHook(() => (invoked++, ""), diagnostics)

    await hook(completedTool("read", { filePath: "a.ts" }))
    await hook(completedTool("future_vendor_tool", {}))
    await hook({ event: { type: "session.idle", properties: { sessionID: "session-123" } } } as Parameters<typeof hook>[0])

    expect(invoked).toBe(0)
    expect(diagnostics).toEqual([])
  })

  test("malformed native event envelopes are observable and fail open", async () => {
    const diagnostics: DaylogDiagnostic[] = []
    let invoked = 0
    const hook = await eventHook(() => (invoked++, ""), diagnostics)
    const cases = [
      { event: null },
      { event: { properties: {} } },
    ]

    for (const input of cases) {
      await expect(hook(input as Parameters<typeof hook>[0])).resolves.toBeUndefined()
    }
    expect(invoked).toBe(0)
    expect(diagnostics.map(({ kind }) => kind)).toEqual([
      "malformed-event",
      "malformed-event",
    ])
  })

  test("malformed relevant events and explicit workdirs fail open", async () => {
    const diagnostics: DaylogDiagnostic[] = []
    let invoked = 0
    const hook = await eventHook(() => (invoked++, ""), diagnostics)
    const cases = [
      { event: { type: "session.created", properties: { info: { id: "", directory: "/repo" } } } },
      { event: { type: "session.created", properties: { info: { id: "s", directory: "" } } } },
      { event: { type: "message.part.updated", properties: { part: { type: "tool" } } } },
      completedTool("edit", { filePath: "a.ts", workdir: "" }),
      completedTool("bash", { command: "git status", workdir: 42 }),
    ]

    for (const event of cases) {
      await expect(hook(event as Parameters<typeof hook>[0])).resolves.toBeUndefined()
    }
    expect(invoked).toBe(0)
    expect(diagnostics.map(({ kind }) => kind)).toEqual(Array(cases.length).fill("malformed-event"))
  })

  test("policy execution and malformed or unexpected output always fail open", async () => {
    for (const output of [new Error("shell failed"), "not json", JSON.stringify({ unexpected: true })]) {
      const diagnostics: DaylogDiagnostic[] = []
      const hook = await eventHook(() => {
        if (output instanceof Error) throw output
        return output
      }, diagnostics)
      await expect(hook(completedTool("edit", { filePath: "a.ts" }))).resolves.toBeUndefined()
      expect(diagnostics.map(({ kind }) => kind)).toEqual([
        output instanceof Error ? "policy-execution" : "policy-response",
      ])
    }
  })

  test("JSON build failures fail open", async () => {
    const diagnostics: DaylogDiagnostic[] = []
    const hook = await eventHook(() => "", diagnostics)
    const circular: Record<string, unknown> = { filePath: "a.ts" }
    circular.self = circular

    await expect(hook(completedTool("edit", circular))).resolves.toBeUndefined()
    expect(diagnostics[0]!.kind).toBe("malformed-event")
  })

  test("diagnostic and console warning failures remain fail-open", async () => {
    const plugin = createDaylogTriggerPlugin({
      runPolicy: () => { throw new Error("shell failed") },
      diagnose: async () => { throw new Error("logger failed") },
      consoleWarn: () => { throw new Error("console failed") },
    })
    const hook = (await plugin(pluginInput())).event!

    await expect(hook(completedTool("edit", { filePath: "a.ts" }))).resolves.toBeUndefined()
  })

  test("default diagnostics use OpenCode app logging", async () => {
    const entries: unknown[] = []
    const input = pluginInput()
    input.client.app.log = async (entry) => {
      entries.push(entry)
      return { data: true } as Awaited<ReturnType<typeof input.client.app.log>>
    }
    const hook = (await createDaylogTriggerPlugin({ runPolicy: () => "unexpected" })(input)).event!

    await expect(hook(completedTool("edit", { filePath: "a.ts" }))).resolves.toBeUndefined()
    expect(entries).toHaveLength(1)
    expect(entries[0]).toMatchObject({
      body: { service: "daylog-trigger", level: "warn", extra: { kind: "policy-response" } },
    })
  })

  test("OpenCode app logging failures degrade to a guarded console warning", async () => {
    const warnings: unknown[][] = []
    const input = pluginInput()
    input.client.app.log = async () => { throw new Error("app logger failed") }
    const hook = (await createDaylogTriggerPlugin({
      runPolicy: () => "unexpected",
      consoleWarn: (...values) => warnings.push(values),
    })(input)).event!

    await expect(hook(completedTool("edit", { filePath: "a.ts" }))).resolves.toBeUndefined()
    expect(warnings).toHaveLength(1)
    expect(warnings[0]![0]).toContain("diagnostics failed")
  })

  test("default runner delegates bash authoring classification to canonical policy", async () => {
    const { vault } = isolatedPolicyEnvironment()
    const hook = (await DaylogTriggerPlugin(pluginInput(process.cwd()))).event!

    await hook(sessionCreated("session-shell", process.cwd()))
    await hook(completedTool("bash", { command: "git status" }, "session-shell"))
    expect(mintedDaylog(vault)).toBeUndefined()

    await hook(completedTool("bash", { command: "git commit -m done" }, "session-shell"))
    const daylog = mintedDaylog(vault)
    expect(daylog).toBeDefined()
    expect(readFileSync(daylog!, "utf8")).toContain("session opens")
  })

  test("first successful authoring completion resumes without a native SessionStart", async () => {
    const { vault, state } = isolatedPolicyEnvironment()
    const hook = (await DaylogTriggerPlugin(pluginInput(process.cwd()))).event!

    await hook(completedTool("apply_patch", { patchText: "*** Begin Patch\n*** End Patch" }, "resumed-session"))

    expect(existsSync(state)).toBe(true)
    expect(mintedDaylog(vault)).toBeDefined()
    expect(JSON.parse(readFileSync(state, "utf8")).session).toBe("resumed-session")
  })

  test("default module exposes the event hook", async () => {
    const module = await import("../plugins/daylog-trigger")
    expect(typeof module.default).toBe("function")
    const hooks = await module.default(pluginInput())
    expect(typeof hooks.event).toBe("function")
  })
})
