# Codex Workbench

A clean local workspace for building with Codex, VS Code, and Git.

## Layout

- `src/` - application or script source code
- `tests/` - tests and verification helpers
- `docs/` - notes, plans, decisions, and project writeups
- `scripts/` - local automation and utility commands
- `rules/` - live-project coding rules for external linked projects
- `assets/` - images, mockups, sample data, and other project assets
- `projects/` - project dossiers with human maps and project-local AI memory
- `cheatsheets/` - human-facing guide to callable Skills and workflows
- `.ai/` - Codex-facing workspace memory, indexes, attempt notes, and generation metadata

## Daily Flow

1. Open this folder in VS Code.
2. Use the Codex extension from the sidebar or run `codex` in the integrated terminal.
3. Let Codex read `AGENTS.md`, `.ai/index.json`, and `.ai/projects/index.json` before broad exploration.
4. Keep work in small Git commits with clear messages.
5. Use `projects/<slug>/` for project-specific work; put polished general notes in `docs/`.
6. Keep AI scratch context in `.ai/` or the relevant `projects/<slug>/.ai/`.
7. Use `cheatsheets/README.md` when you want to see what workflows or Skills to call.
8. Use `rules/README.md` before asking Codex to change a linked live project.
9. Use explicit `@wb:` workflow codes from `cheatsheets/workflow-codes.md` when you want a bundled macro workflow.
10. Let Codex suggest optional workflows using `cheatsheets/recommendations.md` when they add value.
11. Use `cheatsheets/retrieval-strategies.md` when deciding between grep/index, RAG, or hybrid retrieval.
12. Use `cheatsheets/model-providers.md` before launching local/free or existing-subscription model workflows.
13. Use `cheatsheets/reviewer.md` and `@wb:review` for findings-only review passes after substantive work.
14. Use `docs/ideas.md` as the human-facing inbox for ideas to revisit later.
15. Use `scripts/snapshot-context.ps1 -Bootstrap` for a compact startup block.

## Using The Workbench

Run commands from this folder:

```powershell
cd C:\Users\henke\Documents\Codex\2026-05-23\codex-workbench
```

If PowerShell blocks a script, run the same command through:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <script-path> <arguments>
```

### Set Active Project

Create `.env` from `.env.example` and set the project you are currently working on:

```env
WORKBENCH_ACTIVE_PROJECT=tower-heroes
WORKBENCH_ACTIVE_SOURCE_PATH=D:\GameProjects\TowerHeroes(x)\TowerHeroes
WORKBENCH_ACTIVE_TITLE=Tower Heroes
WORKBENCH_ACTIVE_KIND=unity
```

When `.env` is set, project-aware scripts can use that project without `-Slug`:

```powershell
codex
scripts\start-local-codex.ps1
scripts\start-claude-code.ps1 -Model sonnet
scripts\run-local-review.ps1 -Scope uncommitted
```

If `.env` and the project dossier disagree, `.env` wins and the dossier is synced. Naming a different project in a prompt or passing `-Slug` overrides `.env` for that task.

### Start Normal Codex (important implementation, broad debugging, normal project work)

```powershell
codex
```

### Start Local/Free Codex (simple work, docs, mechanical edits, cheap first pass)

```powershell
scripts\start-local-codex.ps1 -Slug tower-heroes
```

Use the smaller local model:

```powershell
scripts\start-local-codex.ps1 -Slug tower-heroes -Small
```

### Start Claude Code (existing Claude subscription only)

```powershell
scripts\start-claude-code.ps1 -Model sonnet -Slug tower-heroes
```

Inside Claude Code, run this if you want to confirm the login method:

```text
/status
```

It should show your Claude account/subscription, not API billing.

### Switch Back To Codex (close or exit the current Claude/local session first)

```powershell
codex
```

Or start the local/free Codex lane again:

```powershell
scripts\start-local-codex.ps1 -Slug tower-heroes
```

### Review Work (after a substantive change)

```powershell
scripts\run-local-review.ps1 -Slug tower-heroes -Scope uncommitted
```

Run a Claude subscription review only when you explicitly want that second opinion:

```powershell
scripts\run-claude-review.ps1 -Slug tower-heroes -Scope uncommitted -Model sonnet
```

Review scopes:

```text
uncommitted
base:<branch>
commit:<sha>
files:<path1,path2>
```

### Prompting

Write normal prompts. When `.env` is set, you do not need to repeat the project name. Name a project only when `.env` is not set or you want to work against a different project.

The workspace instructs Codex to load the relevant rules/context. If `.env` is set, that active project is the default for project work. If a macro, Skill, review, retrieval plan, Unity check, or provider switch would help, Codex may suggest it.

You can also invoke macros manually when you want a specific workflow:

```text
@wb:review
Project: tower-heroes
Scope: uncommitted
Focus: all
Provider: local
```

Current project slugs:

```text
tower-heroes
brawl-survivors
```

## Customizing The Workbench

Most day-to-day behavior can be adjusted through the human-facing files below.

Workflow macros:

```text
cheatsheets/workflow-codes.md
.ai/workflows/index.json
```

Use these when adding or changing explicit `@wb:` commands.

Skills:

```text
cheatsheets/skills.md
~/.codex/skills/
```

Use these when adding reusable Codex workflows such as project setup, image generation, retrieval planning, or session documentation.

Optional suggestions:

```text
cheatsheets/recommendations.md
.ai/recommendations/index.json
```

Use these when changing when Codex should suggest review, handoff, retrieval planning, Unity checks, or model/provider workflows.

Model/provider behavior:

```text
cheatsheets/model-providers.md
.ai/models/index.json
scripts\start-local-codex.ps1
scripts\start-claude-code.ps1
```

Use these when changing local models, subscription-backed providers, or no-extra-spend guardrails.

Reviewer behavior:

```text
cheatsheets/reviewer.md
scripts\run-local-review.ps1
scripts\run-claude-review.ps1
```

Use these when changing review scope, severity format, or rule-checking behavior.

Live-project rules:

```text
rules/live-project-code-rules.md
projects\<slug>\rules\project-rules.md
```

Use these when changing coding constraints for external projects.

Project dossiers:

```text
projects\<slug>\README.md
projects\<slug>\map\
projects\<slug>\.ai\index.json
```

Use these when updating project descriptions, maps, source paths, or project-specific context.

Core rules to keep intact:

- `@wb:` macros must stay explicit.
- External project edits must read the live-project rules first.
- Unity scene/prefab/settings edits should be narrow and inspectable.
- Model/provider workflows must not add API billing, cloud billing, new subscriptions, or automatic paid fallback.
- `.ai/` is for compact AI context; `docs/`, `cheatsheets/`, `rules/`, and project READMEs are for human-facing instructions.
