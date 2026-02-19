# AGENTS.md

## Mission
Build `phx_react` into a package that gives a smooth first-run experience in a fresh Phoenix app (`greystoke`).

Success means a developer can:
1. Add the dependency.
2. Run `mix phx_react.install`.
3. Run `mix phx.gen.react ...`.
4. Start the app and use generated React pages/actions without manual debugging.

## Read First
- `README.md` (public setup and usage docs; keep this accurate)
- `../manowar/CURRENT_STATUS.md` (current extraction status, caveats, and next steps)

## Scope Rules
- Implement shared behavior in this package (`phx_react`), not in `manowar`.
- Use `manowar` as a reference app for extraction parity and gap discovery.
- Use `greystoke` as the clean-install proving ground.

## Workflow Per Change
1. Make the package change in `phx_react`.
2. Update templates/tasks when needed (`mix phx_react.install`, `mix phx.gen.react`).
3. Update `README.md` in the same change when behavior/setup changes.
4. Validate in `greystoke` from a fresh state (or as close as practical).

## Validation Checklist
- `mix format`
- `mix compile --all-warnings`
- `mix test`
- In `greystoke`, verify:
  - dependency wiring works
  - installer runs cleanly
  - generator output compiles
  - generated routes are correct (prefer explicit `get` routes over `resources` for React controller pages)
  - React shell/page render and actions/channel state flow work end-to-end

## Current Known Gaps (From `CURRENT_STATUS.md`)
- No automatic router injection yet for `phx.gen.react` (routes are printed, manual edits required).
- Generator injection relies on specific anchors:
  - `assets/js/app.tsx` expects `const PAGE_COMPONENTS = {`
  - page registry injection expects current map formatting
- Generated form TS may need manual coercion for numeric/date fields.

## Priorities
1. Improve install/generator reliability in fresh apps.
2. Reduce manual steps and fragile injection assumptions.
3. Add/expand tests for generator output and injections.
4. Keep docs aligned so README matches real behavior exactly.
