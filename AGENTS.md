# Repository guidance

These rules apply to SNOPT.jl and OptimizationSNOPT.jl. The two repositories are
sibling checkouts (`SNOPT.jl/` and `OptimizationSNOPT.jl/` in the same directory) and
carry the same copy of this file.

## The packages

- **SNOPT.jl** wraps the SNOPT 7.7 C interface (`libsnopt7`). `snopt` is the
  high-level entry point; `SnoptA`, `SnoptB`, `SnoptC` with `snopta!`, `snoptb!`,
  `snoptc!` are the low-level interface.
- **OptimizationSNOPT.jl** connects SNOPT.jl to Optimization.jl through
  `SnoptOptimizer`. Its `Project.toml` has `[sources] SNOPT = {path = "../SNOPT.jl"}`,
  so local work always uses the sibling checkout.
- SNOPT is commercial. Neither repository contains the library. Set `SNOPTDIR` to its
  directory; `SNOPT.has_snopt()` reports whether it loaded.

## Priorities

1. Preserve numerical correctness and public API compatibility.
2. Make installation and execution instructions copyable.
3. Prefer clear, direct code over clever abstractions.
4. Explain required domain terms. Do not invent terminology.

## Package invariants

- SNOPT owns one active workspace per Julia process. Workspace creation and solves
  are serialized by `SNOPT_LOCK`.
- Callback arrays have the documented sizes and storage order (Jacobian values in
  `J.nzval` order, column by column).
- Bounds and derivative arrays match the problem dimensions; `±1.0e20` is SNOPT's
  infinite bound.
- Option names and values are normalized before they reach the SNOPT library.
- The solve status is a `SnoptStatus.T` enum whose integer values are the SNOPT 7.7
  status codes. `SNOPT.status_from_code` maps any other code to `SnoptStatus.Unknown`.
  The low-level solve functions and `sol.original.inform` keep the integer code.

## Code and contracts

- Validate unsafe inputs at public boundaries with specific exception types
  (`ArgumentError`, `DimensionMismatch`) and actionable messages.
- State invariants near the code that enforces them.
- Keep comments for non-obvious constraints, safety conditions and design reasons.
- Do not add contract machinery when a plain Julia check is clearer.

## Tests

Run from each repository root:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

- Without a loadable library, the solver tests are skipped and the library-free tests
  still run. Set `SNOPT_REQUIRE_LIBRARY=true` (SNOPT.jl) to make a missing library an
  error. Report every check that was skipped.
- Use test-driven development: write a test that fails for the expected reason, then
  the smallest change that makes it pass. Add one regression test per fixed defect.
- Test observable behaviour, not source text or internal calls. Name test sets after
  the behaviour.
- Use table-driven Julia cases instead of a property-testing dependency. Do not add
  Python-only tools such as Hypothesis, Nagini or Axiomander.
- Run Aqua and Julia's standard analysis before adding a dependency.

## Documentation

Build each manual from its repository root:

```bash
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
SNOPT_DOCS_DEPLOY=false julia --project=docs docs/make.jl   # SNOPT.jl
julia --project=docs docs/make.jl                           # OptimizationSNOPT.jl
```

The doctests run when the library is found; `SNOPT_DOCTESTS=true` or `false`
overrides that. The pages are written to `docs/build/`.

The manuals follow the SciML documentation style:

- Page types: a tutorial (`getting_started.md`, in the "we" voice), how-to pages
  (instructions), explanation pages (impersonal) and API pages. Docstrings are
  impersonal and never address the reader as "you".
- The home page lists its pages with `@contents` blocks, one group heading each, not
  with a table of tasks. A group heading must not repeat a page title.
- API pages render full docstrings with `@docs`, start with an `@index` of the page,
  and are split by audience (SNOPT.jl: high-level, monitoring, low-level).
- Doctests use REPL style (`julia>` prompts with the result below), never the
  script style with `# output`. Do not use `@example` blocks: they always run, and
  SNOPT.jl's manual is built on a GitHub-hosted runner without the SNOPT library.
- The README has an opening paragraph, installation, one REPL-style example in a
  `julia-repl` block, a short paragraph that links to the manual, limits, license and
  acknowledgements. No task tables, option lists or build instructions.
- SNOPT.jl is a complete wrapper. Present `snopt` as the simplest entry point, not as
  the limit of the package.

Writing rules:

- Use Simplified Technical English word choice and the active voice.
- Reference text (docstrings, steps, table cells, error messages) uses short direct
  sentences. Explanatory text (concept pages, opening paragraphs) uses connected
  sentences of varied length.
- Define an abbreviation or SNOPT term on first use, or link to its definition.
- Use the same term for the same concept in both packages, for example "SNOPT status
  code", "workspace", "major iteration".
- Use tables for repeated mappings and comparable results.
- Avoid promotional language, filler and unexplained jargon.

## CI

| Workflow | Runner | Library |
| --- | --- | --- |
| SNOPT.jl `CI.yml`, `Documentation.yml` | GitHub-hosted | none; renders and deploys the manual |
| SNOPT.jl `snopt.selfhosted.yml` | self-hosted, label `snopt` | `/opt/snopt`; solver tests and doctests |
| OptimizationSNOPT.jl `CI.yml`, `Documentation.yml` | self-hosted, labels `deimos`, `snopt` | `/usr/lib` |

A push to `main` deploys the `dev` manual of each package to GitHub Pages.

## Releases

- The version is in `Project.toml`; SNOPT.jl also records changes in `CHANGELOG.md`.
- Both packages are registered in the private registry `Local`
  (`EllissoideRotondo/Registry.jl`) with LocalRegistry.jl:
  `using LocalRegistry; register(pwd(); registry = "Local")`.
- For the General registry, register SNOPT.jl first; OptimizationSNOPT.jl depends on
  it. The first version of a new package must be `0.0.1`, `0.1.0`, `1.0.0` or
  `X.0.0`. The name `SNOPT` needs the "name similarity is okay" override.
- If a version is already in `Local` but not yet in General, a new commit changes its
  tree hash. Update `git-tree-sha1` in `Local` to the new `HEAD^{tree}`, or release a
  new version.

## Before completion

1. Run both test suites.
2. Build both manuals.
3. Run the README and manual examples when the library is available.
4. Check commands, links, option names and cross-package terms.
5. Review the diff for unrelated API or behaviour changes.

If the SNOPT library is unavailable, report each skipped check.
