# AGENTS.MD

Justin owns this. Start: say hi + 1 motivating line.
Work style: telegraph; noun-phrases ok; drop grammar; min tokens.

## Agent Protocol
- Contact: Justin Moon (mail@justinmoon.com).
- Workspace: `~/code`. Missing justinmoon repo: clone `https://github.com/steipete/<repo>.git`.
- 3rd-party/non-justinmoon (don't hesitate): clone under `~/code/oss`.
- Files: repo or `~/Projects/agent-scripts`.
- Reviews: use `crank review` or local git diff (no GitHub-only workflow).
- “Make a note” => edit AGENTS.md (shortcut; not a blocker).
- Guardrails: use `trash` for deletes.
- Need upstream file: stage in `/tmp/`, then cherry-pick; never overwrite tracked.
- Bugs: add regression test when it fits.
- Keep files <~500 LOC; split/refactor as needed.
- Commits: Conventional Commits (`feat|fix|refactor|build|ci|chore|docs|style|perf|test`).
- Subagents: read `docs/subagent.md`.
- CI: use `just pre-merge` for local checks; land with `crank land`. No GitHub Actions/merge queue.
- Prefer end-to-end verify; if blocked, say what’s missing.
- New deps: quick health check (recent releases/commits, adoption).
- Web: search early; quote exact errors; prefer 2024–2025 sources; fallback Firecrawl (`pnpm mcp:*`) / `mcporter`.
- Oracle: run `npx -y @steipete/oracle --help` once/session before first use.
- Style: telegraph. Drop filler/grammar. Min tokens (global AGENTS + replies).
- Use nix where possible
- Python scripts: prefer `uv run` + inline deps block (`# /// script` / `dependencies = [...]`) at top.
- Be 100% merge conflicts are resolved correctly; ask questions until you are.

## Screenshots (“use a screenshot”)
- Pick newest PNG in `~/Desktop`.
- Verify it’s the right UI (ignore filename).
- Size: `sips -g pixelWidth -g pixelHeight <file>` (prefer 2×).
- Optimize: `imageoptim <file>` (install: `brew install imageoptim-cli`).
- Replace asset; keep dimensions; commit; run gate; verify CI.

## Important Locations
- Configs: `~/configs`
- Code: `~/code`

## Docs
- Start: run docs list (`docs:list` script, or `bin/docs-list` here if present; ignore if not installed); open docs before coding.
- Follow links until domain makes sense; honor `Read when` hints.
- Keep notes short; update docs when behavior/API changes (no ship w/o docs).
- Add `read_when` hints on cross-cutting docs.
- Model preference: latest only. OK: Anthropic Opus 4.5 / Sonnet 4.5 (Sonnet 3.5 = old; avoid), OpenAI GPT-5.2, xAI Grok-4.1 Fast, Google Gemini 3 Flash.

## Build / Test
- Before handoff: run `just pre-merge` (all ci checks).
- CI red: rerun `crank merge --dry-run` (or `just pre-merge`), fix, repeat til green.
- Keep it observable (logs, panes, tails, MCP/browser tools).

## Git
- Safe by default: `git status/diff/log`. Push only when user asks.
- `git checkout` ok for review / explicit request.
- Branch changes require user consent.
- Destructive ops forbidden unless explicit (`reset --hard`, `clean`, `restore`, `rm`, `git worktree prune`, …).
- Remotes under `~/code`
- Commit helper on PATH: `committer` (bash). Prefer it; if repo has `./scripts/committer`, use that.
- Don’t delete/rename unexpected stuff; stop + ask.
- No repo-wide S/R scripts; keep edits small/reviewable.
- Avoid manual `git stash`; if Git auto-stashes during pull/rebase, that’s fine (hint, not hard guardrail).
- If user types a command (“pull and push”), that’s consent for that command.
- No amend unless asked.
- Big review: `git --no-pager diff --color=never`.
- Multi-agent: check `git status/diff` before edits; ship small commits.

## Critical Thinking
- Fix root cause (not band-aid).
- Unsure: read more code; if still stuck, ask w/ short options. Don't guess.
- Conflicts: call out; pick safer path.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.
- Leave breadcrumb notes in thread.

<frontend_aesthetics>
Avoid “AI slop” UI. Be opinionated + distinctive.
</frontend_aesthetics>
