import { afterEach, describe, expect, test } from "bun:test"
import { mkdtempSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { spawnSync } from "node:child_process"
import type { Hooks, PluginInput } from "@opencode-ai/plugin"
import MainBranchGuardPlugin, {
  createMainBranchGuardPlugin,
  type GuardDiagnostic,
  type PolicyRunRequest,
} from "../plugins/main-branch-guard"

const temporaryDirectories: string[] = []

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true })
  }
})

function pluginInput(directory = "/session/root"): PluginInput {
  return {
    directory,
    client: {
      app: {
        log: async () => ({ data: true }),
      },
    },
  } as unknown as PluginInput
}

async function hookFor(
  runPolicy: (request: PolicyRunRequest) => string | Promise<string>,
  diagnostics: GuardDiagnostic[] = [],
  directory?: string,
): Promise<NonNullable<Hooks["tool.execute.before"]>> {
  const plugin = createMainBranchGuardPlugin({
    runPolicy,
    diagnose: async (_input, diagnostic) => {
      diagnostics.push(diagnostic)
    },
  })
  const hooks = await plugin(pluginInput(directory))
  return hooks["tool.execute.before"]!
}

const nativeInput = {
  tool: "bash",
  sessionID: "session-123",
  callID: "call-456",
}

describe("main branch guard adapter", () => {
  test("translates the native context and forwards the command exactly", async () => {
    const requests: PolicyRunRequest[] = []
    const hook = await hookFor((request) => {
      requests.push(request)
      return ""
    })
    const command = "printf '%s\\n' \"$HOME && literal\"\ngit status"

    await hook(nativeInput, { args: { command } })

    expect(requests).toHaveLength(1)
    expect(JSON.parse(requests[0]!.input)).toEqual({
      hook_event_name: "PreToolUse",
      session_id: "session-123",
      tool_name: "Bash",
      cwd: "/session/root",
      tool_input: { command },
    })
  })

  test("uses an explicit tool workdir", async () => {
    const requests: PolicyRunRequest[] = []
    const hook = await hookFor((request) => (requests.push(request), ""))

    await hook(nativeInput, { args: { command: "git status", workdir: "/tool/cwd" } })

    expect(requests[0]!.cwd).toBe("/tool/cwd")
    expect(JSON.parse(requests[0]!.input).cwd).toBe("/tool/cwd")
  })

  test("falls back to the plugin directory", async () => {
    const requests: PolicyRunRequest[] = []
    const hook = await hookFor((request) => (requests.push(request), ""), [], "/fallback/cwd")

    await hook(nativeInput, { args: { command: "git status" } })

    expect(requests[0]!.cwd).toBe("/fallback/cwd")
  })

  test("allows empty policy output", async () => {
    const hook = await hookFor(() => "")
    await expect(hook(nativeInput, { args: { command: "git status" } })).resolves.toBeUndefined()
  })

  test("throws the exact deny reason", async () => {
    const reason = "Refusing exactly this operation"
    const hook = await hookFor(() => JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: reason,
      },
    }))

    await expect(hook(nativeInput, { args: { command: "git commit" } })).rejects.toThrow(reason)
    try {
      await hook(nativeInput, { args: { command: "git commit" } })
    } catch (error) {
      expect((error as Error).message).toBe(reason)
    }
  })

  test("fails open and diagnoses malformed or non-deny output", async () => {
    const diagnostics: GuardDiagnostic[] = []
    const malformed = await hookFor(() => "not json", diagnostics)
    const nonDeny = await hookFor(() => JSON.stringify({
      hookSpecificOutput: { permissionDecision: "allow" },
    }), diagnostics)

    await expect(malformed(nativeInput, { args: { command: "git commit" } })).resolves.toBeUndefined()
    await expect(nonDeny(nativeInput, { args: { command: "git commit" } })).resolves.toBeUndefined()
    expect(diagnostics.map(({ kind }) => kind)).toEqual(["policy-response", "policy-response"])
  })

  test("fails open and diagnoses malformed args", async () => {
    const diagnostics: GuardDiagnostic[] = []
    let invoked = false
    const hook = await hookFor(() => {
      invoked = true
      return ""
    }, diagnostics)

    await expect(hook(nativeInput, { args: { command: 42 } })).resolves.toBeUndefined()
    await expect(hook(nativeInput, { args: null })).resolves.toBeUndefined()
    expect(invoked).toBe(false)
    expect(diagnostics.map(({ kind }) => kind)).toEqual(["malformed-args", "malformed-args"])
  })

  test("fails open and diagnoses policy execution failure", async () => {
    const diagnostics: GuardDiagnostic[] = []
    const hook = await hookFor(() => {
      throw new Error("shell failed")
    }, diagnostics)

    await expect(hook(nativeInput, { args: { command: "git commit" } })).resolves.toBeUndefined()
    expect(diagnostics).toHaveLength(1)
    expect(diagnostics[0]!.kind).toBe("policy-execution")
  })

  test("diagnostics failure also fails open", async () => {
    const warnings: unknown[][] = []
    const plugin = createMainBranchGuardPlugin({
      runPolicy: () => {
        throw new Error("shell failed")
      },
      diagnose: async () => {
        throw new Error("logger failed")
      },
      consoleWarn: (...values) => {
        warnings.push(values)
      },
    })
    const hook = (await plugin(pluginInput()))["tool.execute.before"]!

    await expect(hook(nativeInput, { args: { command: "git commit" } })).resolves.toBeUndefined()
    expect(warnings).toHaveLength(1)
    expect(warnings[0]![0]).toContain("diagnostics failed")
  })

  test("reports adapter failures through OpenCode app logging", async () => {
    const entries: unknown[] = []
    const input = pluginInput()
    input.client.app.log = async (entry) => {
      entries.push(entry)
      return { data: true } as Awaited<ReturnType<typeof input.client.app.log>>
    }
    const plugin = createMainBranchGuardPlugin({
      runPolicy: () => "not json",
    })
    const hook = (await plugin(input))["tool.execute.before"]!

    await hook(nativeInput, { args: { command: "git commit" } })
    expect(entries).toHaveLength(1)
    expect(entries[0]).toMatchObject({
      body: {
        service: "main-branch-guard",
        level: "warn",
        extra: { kind: "policy-response" },
      },
    })
  })

  test("ignores non-bash tools without invoking policy", async () => {
    let invoked = false
    const hook = await hookFor(() => {
      invoked = true
      return ""
    })

    await hook({ ...nativeInput, tool: "shell" }, { args: { command: "git commit" } })
    expect(invoked).toBe(false)
  })

  test("default runner invokes the canonical policy engine", async () => {
    const directory = mkdtempSync(join(tmpdir(), "main-branch-guard-plugin."))
    temporaryDirectories.push(directory)
    const initialized = spawnSync("git", ["init", "-b", "main", directory], { encoding: "utf8" })
    expect(initialized.status).toBe(0)
    const hooks = await MainBranchGuardPlugin(pluginInput(directory))
    const hook = hooks["tool.execute.before"]!

    await expect(hook(nativeInput, { args: { command: "git commit -m seed" } }))
      .rejects.toThrow("Refusing: this would commit straight to 'main'")
  })

  test("module exposes a loadable default Plugin", async () => {
    const module = await import("../plugins/main-branch-guard")
    expect(typeof module.default).toBe("function")
    const hooks = await module.default(pluginInput())
    expect(typeof hooks["tool.execute.before"]).toBe("function")
  })
})
