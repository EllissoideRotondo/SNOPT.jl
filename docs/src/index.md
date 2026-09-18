```@meta
CurrentModule = SNOPT
```

# SNOPT.jl

SNOPT.jl is an unofficial Julia interface to
[SNOPT](https://ccom.ucsd.edu/~optimizers/solvers/snopt/). SNOPT solves smooth,
constrained nonlinear optimization problems.

The package provides [`snopt`](@ref) as its main Julia entry point and three
low-level interfaces for native SNOPT features.

!!! note "Commercial solver required"
    Obtain a SNOPT license and a compatible `libsnopt7` shared library.
    The Julia package does not include either item.

## Choosing an interface

| Need | Interface |
| --- | --- |
| Direct solve with user derivatives | [`snopt`](@ref) |
| Optimization.jl and automatic differentiation | OptimizationSNOPT.jl |
| Linear rows or finite-difference derivatives | [`SnoptA`](@ref) |
| Separate low-level objective and constraint callbacks | [`SnoptB`](@ref) |
| One combined low-level callback | [`SnoptC`](@ref) |
| Reuse one workspace for a true hot start | [`SnoptA`](@ref), [`SnoptB`](@ref), or [`SnoptC`](@ref) |

Use
[OptimizationSNOPT.jl](https://github.com/EllissoideRotondo/OptimizationSNOPT.jl)
for Optimization.jl problems and automatic differentiation.

Use a low-level interface only when [`snopt`](@ref) cannot represent a required
native feature. [`SnoptA`](@ref) supports explicit linear rows and lets SNOPT
estimate missing derivatives. All low-level interfaces can reuse one workspace
for a true hot start.

## Getting started

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
- [Troubleshooting](@ref) covers library discovery and platform errors.
- [API reference](@ref) lists public types and functions.

## Concurrency

SNOPT owns one active Fortran workspace per process.
Concurrent calls to [`snopt`](@ref) are serialized, so threaded solves run sequentially.
Manage low-level workspaces from one task; creating a workspace closes the previous one.

Use separate Julia processes for parallel solves.
