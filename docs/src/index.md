```@meta
CurrentModule = SNOPT
```

# SNOPT.jl

SNOPT.jl is an unofficial Julia interface to
[SNOPT](https://ccom.ucsd.edu/~optimizers/solvers/snopt/). SNOPT solves smooth,
constrained nonlinear optimization problems.

The package provides three low-level interfaces. It also provides [`snopt`](@ref)
as the main Julia entry point.

!!! note "Commercial solver required"
    Obtain a SNOPT license and a compatible `libsnopt7` shared library.
    The Julia package does not include either item.

## Interfaces

| Need | Interface |
| --- | --- |
| Managed workspace and split callbacks | [`snopt`](@ref) |
| Separate objective and constraint callbacks | [`SnoptB`](@ref) |
| One combined callback | [`SnoptC`](@ref) |
| Stacked rows and separate derivative structure | [`SnoptA`](@ref) |

Use
[OptimizationSNOPT.jl](https://EllissoideRotondo.github.io/OptimizationSNOPT.jl/dev/)
for Optimization.jl problems and automatic differentiation.

## Getting started

Complete [Installation](@ref) before running this example.

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

## Documentation

- [Installation](@ref) covers package and SNOPT library setup.
- [High-level interface](@ref) documents the recommended `snopt` function.
- [Examples](@ref) provides complete unconstrained and constrained problems.
- [Low-level interface](@ref) covers manual workspaces and native problem types.
- [API reference](@ref) lists public types and functions.

## Concurrency

SNOPT owns one active Fortran workspace per process.
Concurrent calls to [`snopt`](@ref) are serialized, so threaded solves run sequentially.
Manage low-level workspaces from one task; creating a workspace closes the previous one.

Use separate Julia processes for parallel solves.
