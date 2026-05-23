# Projects

Each folder in this directory is a project dossier.

A project dossier is a clean container for one project only:

- `README.md` is the human entry point.
- `map/` contains small human-readable mapping documents.
- `.ai/index.json` contains compact AI-facing project context.
- `.ai/sessions/` contains explicit documented sessions.

Use `scripts/new-project.ps1` to create a new dossier.

Unity projects normally stay under `D:\GameProjects` and are referenced from a dossier with `-Kind unity -SourcePath <path>`.
