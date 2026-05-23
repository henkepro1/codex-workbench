# Workflow

## Starting Work

Open the workspace:

```powershell
code C:\Users\henke\Documents\Codex\2026-05-23\codex-workbench\codex-workbench.code-workspace
```

Run Codex in the integrated terminal:

```powershell
codex
```

## Git Basics

Check status:

```powershell
git status
```

Create a commit:

```powershell
git add .
git commit -m "Describe the change"
```

## AI Workspace Flow

Skill and workflow cheatsheets:

```powershell
Get-Content cheatsheets\README.md
```

Start a compact context snapshot:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\snapshot-context.ps1
```

Start a compact bootstrap snapshot:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\snapshot-context.ps1 -Bootstrap
```

Validate and refresh the AI indexes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\update-ai-index.ps1
```

Create an attempt note when a task fails or stalls:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\new-attempt-note.ps1 -TaskName "Describe the task"
```

Remember persistent feedback:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\remember-feedback.ps1 -Title "Preference title" -Rule "What to remember" -Why "Why it matters" -WhenToApply "When Codex should apply it"
```

Record a durable decision:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\new-decision.ps1 -Title "Decision title" -Decision "What was decided" -Why "Why this won"
```

Create a lightweight handoff:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\write-handoff.ps1 -Slug "my-project" -Summary "What was done" -Next "Where to start next"
```

Register a useful generated asset:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\register-asset.ps1 -Id "asset-id" -Type image -Path "assets\asset.png" -Status accepted
```

Use `.ai/` for AI-facing context and `docs/` for human-facing documentation.

## Project Dossiers

Create a project dossier:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\new-project.ps1 -Title "My Project"
```

Create a dossier that points to an external source path:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\new-project.ps1 -Title "My Project" -SourcePath "C:\path\to\source"
```

Create a Unity dossier:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\new-project.ps1 -Title "My Game" -Kind unity -SourcePath "D:\GameProjects\MyGame"
```

Refresh a project index:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\update-project-index.ps1 -Slug "my-project"
```

Refresh Unity context:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\scan-unity-context.ps1 -Slug "my-project"
```

Tail recent Unity errors:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tail-unity-log.ps1 -Severity error
```

Preview a Unity test command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-unity-tests.ps1 -Slug "my-project" -TestMode EditMode -CommandOnly
```

Record an external project change:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\record-project-change.ps1 -Slug "my-project" -Category code -Summary "Changed player movement" -Verification "Not run"
```

Create a compact snapshot for one project:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\snapshot-context.ps1 -Slug "my-project"
```

## Explicit Session Documentation

Only use these commands when you want a documented project session.

Start a session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-project-session.ps1 -Slug "my-project" -Topic "Planning pass" -InitialNote "What this session should capture"
```

Add a timestamped progress note:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\add-project-session-note.ps1 -Slug "my-project" -Kind progress -Title "Implementation pass" -Text "What changed and why"
```

Conclude the active session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\conclude-project-session.ps1 -Slug "my-project" -Summary "Final result and next steps"
```
