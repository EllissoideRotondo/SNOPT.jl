# SNOPT.jl

[![CI](https://github.com/EllissoideRotondo/SNOPT.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/EllissoideRotondo/SNOPT.jl/actions/workflows/CI.yml)
[![docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://EllissoideRotondo.github.io/SNOPT.jl/dev/)

SNOPT.jl is an unofficial Julia interface to
[SNOPT](https://ccom.ucsd.edu/~optimizers/solvers/snopt/), a commercial solver for
large, sparse, constrained nonlinear optimization problems. The package wraps all
three SNOPT solver interfaces, `snOptA`, `snOptB` and `snOptC`, so that linear
constraints, finite-difference derivatives, warm and hot starts, and specs files are
available from Julia. For most problems, the function `snopt` is the simplest entry
point: it takes the objective, the constraints and their first derivatives as Julia
functions, and returns the solution.

SNOPT.jl is the right choice for calling SNOPT directly with derivatives written by
hand. For automatic differentiation, or to compare SNOPT with other solvers, use
[OptimizationSNOPT.jl](https://github.com/EllissoideRotondo/OptimizationSNOPT.jl)
with [Optimization.jl](https://docs.sciml.ai/Optimization/stable/) instead.

## Installation

SNOPT.jl needs Julia 1.11 or later and a licensed SNOPT 7.7 library, `libsnopt7`,
that includes the [snopt-interface](https://github.com/snopt/snopt-interface) C
functions. SNOPT.jl does not include SNOPT; the library and the license are
available from the SNOPT distributors.

```julia
using Pkg
Pkg.add("SNOPT")
```

Before starting Julia, set `SNOPTDIR` to the directory that contains the library:

```bash
export SNOPTDIR=/path/to/snopt/lib
```

Check that SNOPT.jl finds the library (add `--project=...` if you installed it in a
project environment):

```bash
julia -e 'using SNOPT; @assert SNOPT.has_snopt(); println(SNOPT.libsnopt7)'
```

On Windows, in PowerShell:

```powershell
$env:SNOPTDIR = "C:\path\to\snopt\lib"
julia -e "using SNOPT; @assert SNOPT.has_snopt(); println(SNOPT.libsnopt7)"
```

The [installation guide](https://EllissoideRotondo.github.io/SNOPT.jl/dev/installation/)
gives the search order, the supported platforms and help for a library that does not load.

## Example

Minimize `(x₁ - 1)² + (x₂ - 2)²` with `-10 ≤ xᵢ ≤ 10`:

```julia
using SNOPT

objective(x) = (x[1] - 1.0)^2 + (x[2] - 2.0)^2

function gradient!(g, x)
    g[1] = 2.0 * (x[1] - 1.0)
    g[2] = 2.0 * (x[2] - 2.0)
    return nothing
end

result = snopt(objective, gradient!, [0.0, 0.0]; lb = -10.0, ub = 10.0)

result.status_symbol   # :Solve_Succeeded
result.x               # ≈ [1.0, 2.0]
```

`gradient!` must write every entry of `g`. For nonlinear constraints, add the
keywords `eval_con`, `eval_jac`, `lcon` and `ucon`, as the
[getting started tutorial](https://EllissoideRotondo.github.io/SNOPT.jl/dev/getting_started/)
shows.

## Documentation

| Task | Function | Guide |
| --- | --- | --- |
| Install SNOPT.jl and fix a library that does not load | `SNOPT.has_snopt` | [Installation](https://EllissoideRotondo.github.io/SNOPT.jl/dev/installation/) |
| Solve a problem with bounds and constraints | `snopt` | [Getting started](https://EllissoideRotondo.github.io/SNOPT.jl/dev/getting_started/) |
| Set tolerances, limits and output files | `options` keyword | [Set solver options](https://EllissoideRotondo.github.io/SNOPT.jl/dev/howto/options/) |
| Print progress or stop a solve early | `snlog`, `snstop` keywords | [Monitor and stop a solve](https://EllissoideRotondo.github.io/SNOPT.jl/dev/howto/monitoring/) |
| Start from a previous solution | `start`, `basis` keywords | [Warm and hot starts](https://EllissoideRotondo.github.io/SNOPT.jl/dev/howto/warm_start/) |
| Use finite differences or linear rows | `SnoptA`, `snopta!` | [Low-level interface](https://EllissoideRotondo.github.io/SNOPT.jl/dev/howto/lowlevel/) |
| Understand status codes and iterations | `SNOPT_STATUS` | [Solver concepts](https://EllissoideRotondo.github.io/SNOPT.jl/dev/concepts/) |
| Look up a function or a type | | [API reference](https://EllissoideRotondo.github.io/SNOPT.jl/dev/api/) |

## Limits

- One Julia process runs one SNOPT solve at a time. Use several processes for
  parallel solves.
- `snopt` needs exact first derivatives. For finite differences, use `SnoptA`.
- Windows needs a `libsnopt7.dll` built with MinGW. Apple silicon is not supported.

[Solver concepts](https://EllissoideRotondo.github.io/SNOPT.jl/dev/concepts/#Limits)
lists all limits.

## Build the documentation

From the repository root:

```bash
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
SNOPT_DOCS_DEPLOY=false julia --project=docs docs/make.jl
```

The build runs the examples in the manual when it finds the SNOPT library; set
`SNOPT_DOCTESTS=false` to skip them. The pages are written to `docs/build/`.

## License

SNOPT.jl is released under the MIT License. SNOPT is a separate commercial product
with its own license; see [THIRD_PARTY_NOTICE.md](THIRD_PARTY_NOTICE.md).

## Acknowledgements

SNOPT.jl draws on earlier Julia wrappers:
[snopt/SNOPT7.jl](https://github.com/snopt/SNOPT7.jl),
[byuflowlab/Snopt.jl](https://github.com/byuflowlab/Snopt.jl) and
[Yuricst/joptimise](https://github.com/Yuricst/joptimise).
OpenAI Codex and Anthropic Claude Code assisted with documentation, concurrency
safeguards, tests and code review.
