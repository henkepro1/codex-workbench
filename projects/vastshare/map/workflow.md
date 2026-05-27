# Workflow

Use this file for project-specific commands, test steps, build steps, and release notes.

## How to run

This project was generated from the workbench app template (`D:\GameProjects\_template-app`).

```powershell
cd D:\GameProjects\vastshare
pnpm install
pnpm dev      # auto-runs env+db setup, migrations, and seed on first run
```

That's it. API on <http://localhost:4000>, app on <http://localhost:8081>. In the Metro terminal: `w` opens Expo web, `i`/`a` open iOS/Android simulators.

### Other useful scripts

- `pnpm bootstrap`   force a full setup re-run (useful after `pnpm db:reset`)
- `pnpm db:reset`    wipe and re-migrate the database
- `pnpm db:studio`   open Prisma Studio (visual DB inspector)
- `pnpm db:down`     stop the Postgres container
- `pnpm test`        run all suites

### Layout

- `apps/api/`         Fastify + Prisma backend (TypeScript)
- `apps/mobile/`      Expo (RN + web) frontend (TypeScript)
- `packages/shared/`  zod DTOs shared between the two
- `scripts/setup.mjs` first-run bootstrap (env + docker + migrations + seed)
