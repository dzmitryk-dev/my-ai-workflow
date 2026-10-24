// git-approval — require an explicit approval for every `git commit` / `git push`.
//
// Why a plugin instead of only a permissions rule:
//
//   {"action":"shell","resource":"git commit *","effect":"ask"}
//
// is resolved once and offers "Allow always". Choosing it persists a durable,
// project-scoped `allow` rule, and from then on the static rule never prompts
// again — which is exactly the hole a rule cannot close by itself.
//
// `ctx.permission.hook("evaluate")` runs after configured rules *and* saved
// approvals, and may rewrite the effect. Re-setting it to "ask" here restores
// the prompt on every single command, no matter what was approved before.
//
// A configured `deny` is final and never reaches this hook, so the hook only
// ever escalates allow -> ask and can never weaken a deny.

type Evaluation = {
  action: string
  resources: readonly string[]
  effect: "allow" | "ask" | "deny"
  message?: string
}

// Deliberately loose. `git -c core.pager=cat commit`, `env X=1 git commit`,
// `sh -c 'git push'` and `cd sub && git commit` must all match, so we look for
// a `git` token followed anywhere by the subcommand rather than trying to
// re-implement OpenCode's shell parser. False positives (`git log --grep push`)
// only cost an extra prompt, never a silent allow.
const GIT_MUTATION = /\bgit\b[\s\S]*\b(commit|push)\b/

export default {
  id: "git-approval",

  async setup(ctx: any) {
    await ctx.permission.hook("evaluate", (event: Evaluation) => {
      if (event.action !== "shell") return
      if (event.effect === "deny") return

      const commands = event.resources ?? []
      if (!commands.some((command) => GIT_MUTATION.test(String(command)))) return

      event.effect = "ask"
      event.message = "commit/push requires explicit approval"
    })
  },
}
