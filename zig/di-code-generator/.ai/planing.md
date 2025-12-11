# PLAN: DI Generator MVP

Date: 2025-12-11

Purpose
- Clearly and actionably specify the MVP for the code generator for Dependency Injection (DI) patterns described in `agents.md`.

MVP Scope
- Implement a tool that analyzes a TypeScript code tree and generates the minimum necessary boilerplate to facilitate the creation and registration of services in DI containers using the `use()` pattern.
- The MVP will focus on TypeScript projects (not deep Zig parsing). It assumes source projects use ES modules (`.ts`/`.tsx` extension).

Inputs (what the tool will analyze)
- Root code directory (e.g., `src/` or `packages/my-package/src`).
- Files matching configurable patterns (default: `register*.ts`, `*.register.ts`) or exporting a function named `registerDeps`.
- Optional: a configuration file `di-gen.config.json` / `di-gen.config.ts` for rules and mappings.

Outputs (what it will generate)
- `types.ts` (or update/extend an existing one): define the base `ServicesList` interface where detected services are added.
- `register<Name>.ts`: registration stub that exports the default function `registerDeps(container: ContainerCtx)` and an optional `mock(container: ContainerCtx)` function.
- Optional: `index.ts` or `mainContainer.ts` example file showing consolidated `container.use(...)`.

Generator Behavior
- Dry-run mode (`--dry-run`): list what would be generated without writing files.
- Force overwrite (`--force`): rewrite existing files if needed.
- Don't overwrite by default: if destination file exists, create `*.generated.ts` or fail depending on flag.
- Idempotent generation: running twice without `--force` should not overwrite previously generated files.

CLI Interface (proposal)
- `di-gen generate [--root ./src] [--pattern register*.ts] [--dry-run] [--force] [--out ./generated]`
- `di-gen scan [--root ./src] [--pattern register*.ts]` — detects candidate modules and shows a summary.

Templates (content examples)
- `types.ts`:
  - Exports `interface ServicesList {}` and an alias `export type ContainerCtx = PreProcessDependencyContainerWithUse<ServicesList>`.
- `registerFoo.ts`:
  - Exports `export default function registerDeps(container: ContainerCtx) { ... }`
  - Exports `export function mock(container: ContainerCtx) { ... }` or attaches `registerDeps.mock = mock` according to preference.

Rules and Heuristics
- Service name detection: infer from file name (`registerUserService` -> `userService`) and/or from a comment or named export in the file.
- Typing: if the file exports types or interfaces, prefer referencing those types in `types.ts` via `declare module` declarations to extend `ServicesList`.
- Mocks: generate minimal mock stubs (functions that throw `new Error('not implemented')`) for developers to complete.

Acceptance Criteria
- `di-gen scan` correctly detects candidate modules in a sample repo (expected list).
- `di-gen generate --dry-run` shows the files it would generate.
- `di-gen generate` creates `types.ts` and at least one valid `registerX.ts` in a sample package, without breaking existing code.

Recommended Technology
- Main implementation in `Node.js` + `TypeScript` to leverage TypeScript Compiler API or `ts-morph` for AST analysis and generation.
- CLI packaged as npm package in `packages/di-gen` (if publishing). Optionally a lightweight `Zig` interface that invokes the Node engine.

Work Plan and Milestones (brief estimation)
- Sprint 1 (1-3 days): Final specification + `scan` prototype that lists candidate modules.
- Sprint 2 (2-4 days): Implement `generate --dry-run` that emits paths/templates without writing.
- Sprint 3 (3-7 days): Actual file writing, `--force` handling, idempotence and basic tests.
- Sprint 4 (1-2 days): Create example in `packages/example` and document usage in `zig/di-code-generator/README.md`.

Risks and Open Decisions
- TypeScript parsing: using `ts-morph` makes the task much easier; implementing from scratch in `Zig` increases cost.
- Compatibility with mixed projects (JS + TS) and monorepos: need to define exclusion rules and per-project folders.