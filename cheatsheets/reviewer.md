# Reviewer Workflow

Use reviewer workflows after substantive live-project changes, especially multi-file edits, refactors, Unity lifecycle changes, serialized-reference changes, or performance-sensitive code.

Skip review for trivial text changes, obvious one-line fixes, and non-code work unless the user asks.

## Core Rule

Reviewer workflows report findings only.

They must not patch, edit, rewrite, format, create source files, or "fix while reviewing."

## Default Command

Use local/free review by default:

```powershell
scripts\run-local-review.ps1 -Slug tower-heroes -Scope uncommitted
```

Optional Claude subscription review:

```powershell
scripts\run-claude-review.ps1 -Slug tower-heroes -Scope uncommitted -Model sonnet
```

Claude review is allowed only through the existing Claude.ai subscription lane. It is not an API-billed route.

## Scope Values

- `uncommitted`: staged, unstaged, and untracked work.
- `base:<branch>`: diff against a base branch or ref.
- `commit:<sha>`: one commit.
- `files:<paths>`: comma-separated file paths.

## Focus Values

- `code`: correctness, bugs, and maintainability.
- `architecture`: boundaries, coupling, reuse of existing systems.
- `unity`: Unity lifecycle, serialization, scene/prefab risk, broad lookups.
- `performance`: allocations, hot paths, repeated lookups, avoidable runtime cost.
- `all`: default combined review.

## Findings Format

Use this structure:

```markdown
## CRITICAL

- path/file.cs:123 - Rule or bug. Explain impact and exact fix direction.

## WARNING

- path/file.cs:45 - Risk or likely cleanup.

## NOTE

- path/file.cs:67 - Informational observation.

## Verified Clean

- Rule or area checked with no findings.
```

If there are no material findings, say `No findings`.

## Checklist

Review against:

- `AGENTS.md`
- `rules/live-project-code-rules.md`
- `projects/<slug>/rules/project-rules.md`
- `projects/<slug>/.ai/index.json`
- `projects/<slug>/.ai/engine/unity/index.json` for Unity projects

Look for:

- behavior changes not requested by the user
- hidden fallbacks or swallowed errors
- broad Unity lookups such as `FindObjectOfType`, `FindAnyObjectByType`, broad `Find`, or repeated unchecked `GetComponent`
- new god classes or mixed responsibilities
- unused abstractions or new systems where existing systems should be reused
- hot-path allocations, LINQ in per-frame paths, and repeated searches
- serialized field/reference risks
- missing verification or stale context after Unity-relevant changes
