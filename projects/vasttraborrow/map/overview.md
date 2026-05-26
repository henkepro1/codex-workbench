# Overview

Project: VästtraBorrow

## Purpose

Modern mobile app for sharing Västtrafik travel cards ("låna kort").

Users register their period card, list it for lend in a Standard or Fast-Sell tier, and a
FIFO matching engine pairs them with borrowers. A 4-unique-recipients-per-month cap protects
the lender. Pricing is dynamic — supply-aware — within a per-card-type band. The platform takes
a configurable commission (default 10%) deducted from the lender's payout. The route planner
calls the real Västtrafik PlaneraResa API and recommends which card type the journey would need.

## Current State

Scaffolded from the workbench app template (`D:\GameProjects\_template-app`). Backend Fastify +
Prisma, mobile Expo (RN + web), Postgres in Docker. Payment runs through a `PaymentProvider`
interface — `FakeProvider` today, `SwishProvider` is a stub ready to be implemented.

UI is Swedish-first with full English translation and a system / light / dark theme. Logger is a
singleton with five levels. Errors never hard-crash the app.

## Stack snapshot

- Backend: Node 20+, Fastify 5, Prisma 6, Postgres 16, Argon2id, JWT access + refresh, Vitest
- Mobile: Expo SDK 52, React Native 0.76, Expo Router, NativeWind (Tailwind), zustand, i18next, axios
- Monorepo: pnpm workspaces (`apps/api`, `apps/mobile`, `packages/shared`)

## Important Links

- Source path: D:\GameProjects\vasttraborrow
- Workflow / run commands: map/workflow.md
- Source map: map/source.md
- Project rules: rules/project-rules.md
- AI index: ../.ai/index.json
