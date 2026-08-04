# Bang-input guard (#155)

Text typed after `!` in the Claude Code prompt runs in your shell. On
2026-08-04 a five-line chat reply was typed in that mode; it was
harmless only because no line began with a real command name. Two
layers guard against a repeat.

## Layer 1 — the hook (installed with the plugin)

`plugin/scripts/user-prompt-guard.sh` runs on `UserPromptSubmit`. A
prompt starting with `!` is checked against the same pattern families
the agent-side bash guard uses. Blocked, with the reason shown:

- destructive git (`reset --hard`, `clean -f`, force push)
- recursive `rm` outside `/tmp` and `.claude/tmp`
- piping downloaded content into a shell (`curl ... | sh`)
- writes touching enforcement files or workflow state

Everything else — normal prompts and harmless bang commands — passes
untouched.

**Known unknown, recorded on #155:** the docs say this hook fires
before the prompt is processed and exit 2 blocks it. Whether that is
before the shell executes the bang line is unverified. If the hook
fires first, execution is prevented; if not, the block still keeps the
line and its output out of the conversation, and Layer 2 covers
execution.

### Verifying the ordering (one minute, needs a human)

Type this into the Claude Code prompt in any project with WFM active:

```
!touch /tmp/wfm-guard-probe && git push --force
```

The line matches the force-push pattern, so the hook should block it.
Then check: if `/tmp/wfm-guard-probe` does **not** exist, the hook ran
before the shell — full protection. If it exists, the shell ran first —
Layer 2 is the execution guard. Either way, comment the result on #155.

## Layer 2 — optional zsh guard (execution-side, user-installed)

Claude Code runs bang lines through your shell, so a `preexec` hook in
`~/.zshrc` can refuse them at execution time regardless of hook
ordering:

```zsh
# WFM bang-input guard — refuse obviously destructive one-liners that
# arrive via Claude Code's "!" mode (or any other injection into this
# shell). Remove or edit freely; this is a personal safety net.
wfm_guard_preexec() {
  local cmd="$1"
  if [[ "$cmd" =~ 'git[[:space:]]+(reset[[:space:]]+--hard|clean[[:space:]]+-[a-zA-Z]*f|push[[:space:]].*(--force|-f))' ]] \
     || [[ "$cmd" =~ '(curl|wget)[[:space:]].*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh' ]] \
     || [[ "$cmd" =~ 'rm[[:space:]]+-[a-zA-Z]*[rf][a-zA-Z]*[[:space:]]' && ! "$cmd" =~ '(/tmp/|\.claude/tmp/)' ]]; then
    print -u2 "wfm-guard: refusing: $cmd"
    print -u2 "wfm-guard: run it deliberately with 'command <...>' or edit ~/.zshrc to allow."
    setopt ERR_RETURN
    return 130
  fi
}
autoload -Uz add-zsh-hook
add-zsh-hook preexec wfm_guard_preexec
```

Note zsh's `preexec` cannot literally cancel the command in every
configuration; treat this as best-effort and the hook layer as primary.
