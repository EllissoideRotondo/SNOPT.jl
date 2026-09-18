# SNOPT.jl

[![CI](https://github.com/EllissoideRotondo/SNOPT.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/EllissoideRotondo/SNOPT.jl/actions/workflows/CI.yml)
[![docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://EllissoideRotondo.github.io/SNOPT.jl/dev/)

SNOPT.jl is an unofficial Julia interface to
[SNOPT](https://ccom.ucsd.edu/~optimizers/solvers/snopt/). SNOPT solves large,
constrained nonlinear optimization problems.

Use this package for direct access to SNOPT's `snOptA`, `snOptB`, and `snOptC`
interfaces. Use
[OptimizationSNOPT.jl](https://github.com/EllissoideRotondo/OptimizationSNOPT.jl)
for Optimization.jl problems and automatic differentiation.

## Requirements

- Julia 1.10 or later.
- A licensed SNOPT 7.7 shared library that includes the C API provided by
  [`snopt-interface`](https://github.com/snopt/snopt-interface).

You must obtain the SNOPT library and license separately.

## Installation

For a registry installation, run this in your Julia environment:

```julia
import Pkg
Pkg.add("SNOPT")
```

To install from source:

```julia
import Pkg
Pkg.develop(url = "https://github.com/EllissoideRotondo/SNOPT.jl")
```

Set `SNOPTDIR` to the directory that contains `libsnopt7`:

```bash
export SNOPTDIR=/path/to/snopt/lib
```

Windows PowerShell uses this command:

```powershell
$env:SNOPTDIR = "C:\path\to\snopt\lib"
```

Verify library discovery from the environment where you installed SNOPT:

```bash
julia -e 'using SNOPT; @assert SNOPT.has_snopt(); println(SNOPT.libsnopt7)'
```

See the [installation guide](https://EllissoideRotondo.github.io/SNOPT.jl/dev/installation/)
for library names, search paths, licensing, and platform limits.

## Getting started

The high-level [`snopt`](https://EllissoideRotondo.github.io/SNOPT.jl/dev/interface/)
function manages the workspace and returns a `SnoptResult`.

```julia
using SNOPT

objective(x) = (x[1] - 1.0)^2 + (x[2] - 2.0)^2

function gradient!(gradient, x)
    gradient[1] = 2.0 * (x[1] - 1.0)
    gradient[2] = 2.0 * (x[2] - 2.0)
    return nothing
end

result = snopt(
    objective,
    gradient!,
    [0.0, 0.0];
    lb = -10.0,
    ub = 10.0,
    options = ["Major print level" => 0],
)

result.status_symbol
result.x          # approximately [1.0, 2.0]
result.objective  # approximately 0.0
```

The gradient callback must fill every entry of `gradient`. It may return any
value because SNOPT uses the mutated array.

## Examples

With Julia and the licensed library installed, run these commands from the repository root:

```bash
julia --project=. examples/unconstrained.jl
julia --project=. examples/hs71.jl
```

The Hock-Schittkowski 71 example includes bounds and constraints.
It also supplies a constraint Jacobian.
A Jacobian is the matrix of constraint derivatives.
Both scripts write a solver log beside the script, with the extension `.out`.

## Interfaces

| Need | Interface |
| --- | --- |
| Managed workspace and split callbacks | `snopt` |
| Separate objective and constraint callbacks | `SnoptB` |
| One combined callback | `SnoptC` |
| Stacked rows and separate derivative structure | `SnoptA` |

The [documentation](https://EllissoideRotondo.github.io/SNOPT.jl/dev/)
contains callback contracts, warm starts, monitoring, and low-level examples.

## Concurrency

SNOPT owns one active Fortran workspace per process.
Concurrent calls to `snopt` are serialized, so threaded solves run sequentially.
Manage low-level workspaces from one task; creating a workspace closes the previous one.

Use separate Julia processes for parallel solves.

## Testing

Run the test suite from the repository root:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Solver tests run when Julia finds `libsnopt7`. Library discovery tests remain
available without it.

## Platform support

- Linux is tested with a compatible `libsnopt7.so`.
- Intel macOS is expected to work, but is not tested by the maintainers.
- Apple Silicon is not currently supported.
- Windows requires a MinGW-built `libsnopt7.dll`.

The vendor's Intel-built Windows library is not compatible with this package.
Use the MinGW build or Windows Subsystem for Linux.

## License

SNOPT.jl uses the MIT License. SNOPT is a separate commercial product.
See [THIRD_PARTY_NOTICE.md](THIRD_PARTY_NOTICE.md).

## Acknowledgements

This package draws on prior Julia wrappers:

- [snopt/SNOPT7.jl](https://github.com/snopt/SNOPT7.jl)
- [byuflowlab/Snopt.jl](https://github.com/byuflowlab/Snopt.jl)
- [Yuricst/joptimise](https://github.com/Yuricst/joptimise)

OpenAI Codex and Anthropic Claude Code assisted with documentation, concurrency
safeguards, tests, and code review.
