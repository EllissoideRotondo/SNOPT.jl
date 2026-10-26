# SNOPT.jl

[![CI](https://github.com/EllissoideRotondo/SNOPT.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/EllissoideRotondo/SNOPT.jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/EllissoideRotondo/SNOPT.jl/graph/badge.svg)](https://codecov.io/gh/EllissoideRotondo/SNOPT.jl)
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

SNOPT.jl needs Julia 1.10 or later and a licensed SNOPT 7.7 library, `libsnopt7`,
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

Check that SNOPT.jl finds the library. For a package installed in a project
environment, add `--project=/path/to/project` after `julia`.

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

```julia-repl
julia> using SNOPT

julia> objective(x) = (x[1] - 1.0)^2 + (x[2] - 2.0)^2;

julia> function gradient!(g, x)
           g[1] = 2.0 * (x[1] - 1.0)
           g[2] = 2.0 * (x[2] - 2.0)
           return nothing
       end;

julia> result = snopt(objective, gradient!, [0.0, 0.0]; lb = -10.0, ub = 10.0);

julia> result.status
SnoptStatus.Optimal = 1

julia> round.(result.x; digits = 6)
2-element Vector{Float64}:
 1.0
 2.0
```

`gradient!` must write every entry of `g`. For nonlinear constraints, add the
keywords `eval_con`, `eval_jac`, `lcon` and `ucon`, as the
[getting started tutorial](https://EllissoideRotondo.github.io/SNOPT.jl/dev/getting_started/)
shows.

## Documentation

The [documentation](https://EllissoideRotondo.github.io/SNOPT.jl/dev/) starts with a
[tutorial](https://EllissoideRotondo.github.io/SNOPT.jl/dev/getting_started/) on bounds
and nonlinear constraints. It then gives how-to guides for solver options, monitoring,
warm and hot starts and the low-level interface, explains the SNOPT terms and status
codes, and ends with the API reference.

## Limits

- One Julia process runs one SNOPT solve at a time. Use several processes for
  parallel solves.
- `snopt` needs exact first derivatives. For finite differences, use `SnoptA`.
- Windows needs a `libsnopt7.dll` built with MinGW. Apple silicon is not supported.

[Solver concepts](https://EllissoideRotondo.github.io/SNOPT.jl/dev/concepts/#Limits)
lists all limits.

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
