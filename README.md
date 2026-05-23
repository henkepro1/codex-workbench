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
