// fs-guard — auto-deny shell commands that reach into caches this project
// never needs.
//
// OpenCode's `external_directory` permission only inspects the *working
// directory* of a shell command: `cd ~/.gradle` is rejected, but
// `unzip ~/.gradle/caches/.../thing.jar` is not. Directory inference is
// documented as best-effort, so this hook reads the command string itself.
//
// The blocklist is deliberately small. An agent that cannot find the docs
// should read the repo (or ask Context7), not decompile a Gradle artifact —
// so `~/.gradle` is denied outright, without a prompt. `~/.config/opencode` is
// denied too: this harness must not edit its own guardrails; those are
// installed from the my-ai-workflow repo by `bin/setup`.
//
// It is a text heuristic, not a sandbox: a program that opens an outside file
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

const DENIED = ["~/.gradle", "~/.config/opencode"]

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

function stripQuotes(token: string): string {
  return token.replace(/^['"`]+/, "").replace(/['"`]+$/, "")
}

/**
 * Path-looking tokens in a command.
 *
 * Absolute and home-relative forms are kept as-is; `..`-prefixed tokens are
 * kept so they can be resolved against the working directory. Anything else is
 * a bare command name, a flag, or a repo-relative path, none of which can name
 * a denied directory unless the command changes directory first.
 */
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
    const denied = DENIED.map((entry) => expand(entry, home, cwd))

    await ctx.permission.hook("evaluate", (event: Evaluation) => {
      if (event.action !== "shell") return
      if (event.effect === "deny") return

      for (const command of event.resources ?? []) {
        for (const token of pathTokens(stripCommitMessages(String(command)))) {
          const path = expand(token, home, cwd)
          const hit = denied.find((root) => isInside(path, root))
          if (!hit) continue

          event.effect = "deny"
          event.message = `Blocked by fs-guard: "${path}" is off-limits. Read the repo or the docs instead.`
          return
        }
      }
    })
  },
}
