// Regression test for the fs-guard path resolver.
// Run from the repo root:
//   node --experimental-strip-types integrations/opencode/fs-guard.test.ts
//
// The resolver is the only non-obvious part of the guardrail: `~`, `$HOME`,
// `${HOME}`, absolute paths and `..` traversal all have to land on the same
// canonical directory, or the deny silently misses. Nothing here is
// machine-specific — paths are derived at runtime.
import { homedir } from "node:os"
import { resolve } from "node:path"
import plugin from "./plugins/fs-guard.ts"

const home = homedir()
const repo = resolve(import.meta.dirname, "../..")

let hook: any
const ctx = {
  location: { directory: repo },
  permission: { hook: async (_name: string, fn: any) => { hook = fn } },
}
await (plugin as any).setup(ctx)

const cases: Array<[string, string]> = [
  // Reads of the Gradle cache are denied, however the path is spelled.
  ["unzip ~/.gradle/caches/modules-2/files-2.1/foo/bar.jar", "deny"],
  [`ls ${home}/.gradle`, "deny"],
  ["cat $HOME/.gradle/x", "deny"],
  ["cat ${HOME}/.gradle/x", "deny"],
  ["cat ../../.gradle/caches/x", "deny"],
  ["cat ~/.gradle/x > notes.txt", "deny"],

  // Writing to it is not reading it: no cache contents reach the agent.
  ["echo generated >> ~/.gradle/probe", "allow"],
  ['echo generated >> "~/.gradle/probe"', "allow"],
  ["echo generated > ~/.gradle/probe", "allow"],

  // The harness config is denied in both directions.
  ["cat ~/.config/opencode/opencode.jsonc", "deny"],
  ["cat ${HOME}/.config/opencode/plugins/fs-guard.ts", "deny"],
  ["echo x > ~/.config/opencode/opencode.jsonc", "deny"],
  ["cp something ~/.config/opencode/plugins/fs-guard.ts", "deny"],

  // Data, not paths.
  ['git commit -m "stop reading ~/.gradle"', "allow"],
  ['git commit -m \'x\' -m "~/.gradle"', "allow"],

  ["git status", "allow"],
  ["git commit -m x", "allow"],
  ["awk '{print $1}' file", "allow"],
  ["ls ..", "allow"],
  ["find . -name '*.jar'", "allow"],
  ["npm run build", "allow"],
]

let fail = 0
for (const [command, expected] of cases) {
  const event = { action: "shell", resources: [command], effect: "allow" }
  hook(event)
  const ok = event.effect === expected
  if (!ok) fail++
  console.log(`${ok ? "PASS" : "FAIL"}  ${expected.padEnd(5)}  ${command}`)
}

// The hook may only escalate; it must never weaken an existing deny.
const denied = { action: "shell", resources: ["cat ~/.gradle/x"], effect: "deny" }
hook(denied)
if (denied.effect !== "deny") fail++
console.log(`${denied.effect === "deny" ? "PASS" : "FAIL"}  deny stays final`)

// `read` is owned by the config rules, not this plugin.
const read = { action: "read", resources: ["~/.gradle/x"], effect: "allow" }
hook(read)
if (read.effect !== "allow") fail++
console.log(`${read.effect === "allow" ? "PASS" : "FAIL"}  read untouched (config owns it)`)

process.exit(fail ? 1 : 0)
