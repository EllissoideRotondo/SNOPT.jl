```@meta
CurrentModule = SNOPT
```

# SNOPT.jl: Julia interface to the SNOPT solver

SNOPT.jl is an unofficial Julia interface to
[SNOPT](https://ccom.ucsd.edu/~optimizers/solvers/snopt/), a commercial solver for
large, sparse, constrained nonlinear optimization problems. The package wraps all
three SNOPT solver interfaces, `snOptA`, `snOptB` and `snOptC`, and so gives access to
the SNOPT features, including linear constraints, finite-difference derivatives, warm
and hot starts, and specs files. For most problems, the function [`snopt`](@ref) is the
simplest entry point: it takes the objective, the constraints and their first
derivatives as ordinary Julia functions, manages the SNOPT workspace, and returns the
solution in a [`SnoptResult`](@ref).

SNOPT.jl solves problems of the form

```math
\begin{aligned}
\min_{x \in \mathbb{R}^n} \quad & f(x) \\
\text{subject to} \quad & l_x \le x \le u_x, \\
& l_c \le c(x) \le u_c,
\end{aligned}
```

where ``f`` is the objective, ``c`` is a vector of constraint functions, and the
bounds can be infinite. SNOPT uses a sequential quadratic programming (SQP) method, so
``f`` and ``c`` must be smooth, and their first derivatives must be supplied.

!!! note "SNOPT license required"
    SNOPT.jl does not include SNOPT. A SNOPT license and a compatible `libsnopt7`
    shared library are available from the SNOPT distributors.
    See [Installation](installation.md).

## When to use SNOPT.jl

SNOPT.jl is the right choice for calling SNOPT directly with derivatives written by
hand. Use
[OptimizationSNOPT.jl](https://github.com/EllissoideRotondo/OptimizationSNOPT.jl)
instead to define the problem with
[Optimization.jl](https://docs.sciml.ai/Optimization/stable/), compute derivatives
with automatic differentiation, or compare SNOPT with other solvers through one
interface. OptimizationSNOPT.jl uses SNOPT.jl internally.

## Installation

Install the package with the Julia package manager:

```julia
using Pkg
Pkg.add("SNOPT")
```

Then, before starting Julia, set `SNOPTDIR` to the directory of the SNOPT library:

```bash
export SNOPTDIR=/path/to/snopt/lib
```

[Installation](installation.md) gives the library file names, the search order, the commands for
Windows and the setup checks.

## Contents

### Tutorial and installation

The tutorial solves a first problem with bounds and nonlinear constraints. The
installation page makes the SNOPT library available to Julia.

```@contents
Pages = [
    "getting_started.md",
    "installation.md",
]
Depth = 2
```

### How-to guides

Each guide shows how to do one task with SNOPT.jl.

```@contents
Pages = [
    "howto/options.md",
    "howto/monitoring.md",
    "howto/warm_start.md",
    "howto/lowlevel.md",
]
Depth = 2
```

### Concepts and reference

The concepts page explains the SNOPT terms and status codes. The API reference lists
every exported function and type.

```@contents
Pages = [
    "concepts.md",
    "api.md",
]
Depth = 2
```

## Contributing

- Report bugs and request features on the
  [issue tracker](https://github.com/EllissoideRotondo/SNOPT.jl/issues).
- Before opening a pull request, run the test suite with
  `julia --project=. -e 'using Pkg; Pkg.test()'` from the repository root.
  The solver tests run only when Julia finds a licensed `libsnopt7`.

## Acknowledgements

SNOPT was written by Philip E. Gill, Walter Murray and Michael A. Saunders.
SNOPT.jl draws on earlier Julia wrappers:
[snopt/SNOPT7.jl](https://github.com/snopt/SNOPT7.jl),
[byuflowlab/Snopt.jl](https://github.com/byuflowlab/Snopt.jl) and
[Yuricst/joptimise](https://github.com/Yuricst/joptimise).
