// fs-guard — auto-deny shell commands that read caches this project never
// needs, or that write to the harness's own configuration.
//
// OpenCode's `external_directory` permission only inspects the *working
// directory* of a shell command: `cd ~/.gradle` is rejected, but
// `unzip ~/.gradle/caches/.../thing.jar` is not. Directory inference is
// documented as best-effort, so this hook reads the command string itself.
//
// Presence of a path in a command is not enough to deny it. What matters is
// whether the command *reads* the path:
//
//   cat ~/.gradle/x              read    -> deny
//   unzip ~/.gradle/x/y.jar      read    -> deny
//   echo log >> ~/.gradle/x      write   -> allow (reveals nothing)
//   git commit -m "drop ~/.gradle" data  -> allow
//
// The one exception is the harness's own config directory, which is denied in
// both directions: reading it is leakage, writing it is tampering.
//
// It is a text heuristic, not a sandbox: a program that opens a denied file
// from inside its own logic is invisible here. It does stop the realistic case
// — an agent typing the path of a cache on the command line.

import { homedir } from "node:os"
import { resolve, sep } from "node:path"

type Evaluation = {
  action: string
  resources: readonly string[]
  effect: "allow" | "ask" | "deny"
  message?: string
}

// Denied when read: a build cache the agent has no reason to inspect.
const READ_DENIED = ["~/.gradle"]

// Denied in every position, including as a write target: these are the
// guardrails themselves, and the harness must not edit them.
const WRITE_DENIED = ["~/.config/opencode"]

// `>`, `>>`, `2>`, `&>` and their quoted targets.
const OUTPUT_REDIRECT = /(?:&>>?|\d?>>?)\s*("[^"]*"|'[^']*'|[^\s;|&<>]+)/g

/**
 * Drop quoted `-m`/`--message` values from `git commit` before scanning.
 *
 * A commit message is data, never a path the shell opens — but it is part of
 * the command string, so `git commit -m "stop reading ~/.gradle"` would
 * otherwise be denied. Verified the hard way: it blocked a real commit.
 */
function stripCommitMessages(command: string): string {
  return command.replace(/(\s(?:-m|--message)\s*)("[^"]*"|'[^']*')/g, "$1")
}

/**
 * Drop output-redirect targets. Writing to a path does not read it, and a
 * denied cache target is the tool's business, not a leak to the agent.
 * Input redirects (`<`) are deliberately left in place: those do read.
 */
function stripOutputRedirects(command: string): string {
  return command.replace(OUTPUT_REDIRECT, " ")
}

function stripQuotes(token: string): string {
  return token.replace(/^['"`]+/, "").replace(/['"`]+$/, "")
}

/** Path-looking tokens in a command. */
function pathTokens(command: string): string[] {
  const tokens = command.split(/[\s;|&()<>='",`]+/)
  const paths: string[] = []
  for (const token of tokens) {
    const value = stripQuotes(token)
    if (!value) continue
    if (
      value.startsWith("/") ||
      value.startsWith("~/") ||
      value.startsWith("$HOME/") ||
      value.startsWith("${HOME}/") ||
      value === "~" ||
      value === "${HOME}" ||
      value.startsWith("..")
    ) {
      paths.push(value)
    }
  }
  return paths
}

function expand(path: string, home: string, cwd: string): string {
  if (path === "~" || path === "${HOME}") return home
  if (path.startsWith("~/")) return resolve(home, path.slice(2))
  if (path.startsWith("$HOME/")) return resolve(home, path.slice(6))
  if (path.startsWith("${HOME}/")) return resolve(home, path.slice(8))
  return resolve(cwd, path)
}

function isInside(path: string, root: string): boolean {
  if (!root) return false
  const boundary = root.endsWith(sep) ? root : root + sep
  return path === root || path.startsWith(boundary)
}

export default {
  id: "fs-guard",

  async setup(ctx: any) {
    const home = homedir()
    const cwd = resolve(ctx?.location?.directory ?? process.cwd())
    const readDenied = READ_DENIED.map((entry) => expand(entry, home, cwd))
    const writeDenied = WRITE_DENIED.map((entry) => expand(entry, home, cwd))

    const find = (command: string, roots: string[]): string | undefined => {
      for (const token of pathTokens(command)) {
        const path = expand(token, home, cwd)
        if (roots.some((root) => isInside(path, root))) return path
      }
      return undefined
    }

    await ctx.permission.hook("evaluate", (event: Evaluation) => {
      if (event.action !== "shell") return
      if (event.effect === "deny") return

      for (const resource of event.resources ?? []) {
        const command = stripCommitMessages(String(resource))

        // Config tampering counts in either direction.
        const write = find(command, writeDenied)
        if (write) {
          event.effect = "deny"
          event.message = `Blocked by fs-guard: "${write}" is the harness config, not something an agent may touch.`
          return
        }

        // Cache access counts only where it is read.
        const read = find(stripOutputRedirects(command), readDenied)
        if (read) {
          event.effect = "deny"
          event.message = `Blocked by fs-guard: "${read}" is off-limits. Read the repo or the docs instead.`
          return
        }
      }
    })
  },
}
