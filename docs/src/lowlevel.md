```@meta
CurrentModule = SNOPT
```

# Low-level interface

Use the low-level interface only when [`snopt`](@ref) cannot represent the
problem. Examples include linear objective rows and hot starts.

The low-level types mirror SNOPT's three Fortran entry points.

## Workspace lifecycle

[`initialize`](@ref) creates a [`SnoptWorkspace`](@ref SNOPT.SnoptWorkspace).
The workspace owns SNOPT's work arrays and active Fortran session.

Always close a manually managed workspace:

```julia
using SNOPT

workspace = initialize("", "")
try
    set_option!(workspace, "Major print level", 0)
finally
    close(workspace)
end
```

Prefer the `do` form because it closes the workspace after errors:

```julia
initialize("", "") do workspace
    set_option!(workspace, "Major print level", 0)
end
```

SNOPT owns one active workspace per process. Calling `initialize` closes the
previous active workspace. Workspace creation and solves are serialized.
The `do` block does not hold the lock across user code.
Manage low-level workspaces from one task, including option changes and cleanup.

Do not create several workspaces for parallel solves. Use separate Julia
processes instead.

## Workspace size

Each work array must contain at least 500 elements. `initialize` enforces this
SNOPT requirement.

For a known problem, use [`snmemb`](@ref) to ask SNOPT for minimum sizes:

```julia
memory = snmemb(m, n, neJ, negCon, nnCon, nnObj, nnJac)
workspace = initialize("", "", memory.miniw, memory.minrw)
```

| Name | Meaning |
| --- | --- |
| `m` | Total rows passed to SNOPT. |
| `n` | Design variables. |
| `neJ` | Stored Jacobian entries. |
| `negCon` | Nonlinear constraint derivatives. |
| `nnCon` | Nonlinear constraints. |
| `nnObj` | Variables in the nonlinear objective. |
| `nnJac` | Variables in the nonlinear constraint Jacobian. |

The high-level [`snopt`](@ref) function performs this estimate automatically.

## Set options

[`set_option!`](@ref) calls SNOPT's native option functions.

```julia
set_option!(workspace, "Major iterations limit", 250)
set_option!(workspace, "Major optimality tolerance", 1.0e-8)
set_option!(workspace, "Hessian limited memory")
```

The function requires an open workspace. Invalid options raise an
`ArgumentError`. Use [`read_options`](@ref) to read a specs file.

## Problem types

| Type | SNOPT entry | Callback shape |
| --- | --- | --- |
| [`SnoptB`](@ref) | `snOptB` | Separate objective and constraints. |
| [`SnoptC`](@ref) | `snOptC` | Combined objective and constraints. |
| [`SnoptA`](@ref) | `snOptA` | Stacked row vector and derivative structure. |

All three types extend [`AbstractSnoptProblem`](@ref). [`snopt!`](@ref)
dispatches to the matching in-place solver.

After solving, the problem contains its status, multipliers, and final point.
`SnoptB` and `SnoptC` also store `obj_val`.

## Callback builders

The builders adapt Julia functions to SNOPT's C callback signatures.

| Builder | Julia contract |
| --- | --- |
| [`make_objfun`](@ref) | `eval_obj(x)` and `eval_grad(gradient, x)` |
| [`make_confun`](@ref) | `eval_con(values, x)` and `eval_jac(nonzeros, x)` |
| [`make_dummy_confun`](@ref) | No constraints. |
| [`make_usrfun_c`](@ref) | Combined objective and constraints. |
| [`make_usrfun_a`](@ref) | `eval_F(F, x)` and optional `eval_G(G, x)`. |
| [`make_snlog`](@ref) | Major-iteration progress events. |
| [`make_snstop`](@ref) | Major-iteration stop events. |

Mutation callbacks must fill every requested entry. Array lengths and storage
order must match the problem definition.

Problem-evaluation builders accept an optional `callback` keyword. It receives
an event after each evaluation. Return `false` to request a stop.

## Minimal `SnoptA` construction

`SnoptA` represents the objective and constraints as rows in one vector. This
example omits `eval_G`, so SNOPT estimates the derivative by finite differences.
The low-level index arrays use `Int32` because they pass directly to SNOPT.

```jldoctest snopta
using SNOPT

initialize("", "") do workspace
    set_option!(workspace, "Major print level", 0)
    set_option!(workspace, "Derivative option", 0)

    usrfun = make_usrfun_a((F, x) -> (F[1] = (x[1] - 2.0)^2))
    problem = SnoptA(
        workspace,
        1, 1,
        0.0, 1,
        Int32[], Int32[], Float64[],
        Int32[1], Int32[1],
        [-10.0], [10.0],
        [-1.0e20], [1.0e20],
        [0.0], zeros(Int32, 1), zeros(1),
        zeros(1), zeros(Int32, 1), zeros(1),
        0, 0, 0, 0.0,
        usrfun,
    )

    @assert snopta!(problem) == 1
    @assert isapprox(problem.x[1], 2.0; atol = 1.0e-4)

    # Reuse the problem and workspace state for a true hot start.
    problem.x[1] = 2.1
    @assert snopta!(problem; start = "Hot") == 1
    @assert isapprox(problem.x[1], 2.0; atol = 1.0e-4)
end

# output
```

The second solve must reuse the same problem and open workspace. Creating a new
workspace discards the factorization state required by `start = "Hot"`.

## Minimal `SnoptB` construction

This example shows the required extended arrays. SNOPT appends one slack
variable per row. A slack converts a constraint row into a bounded variable.

```jldoctest snoptb
using SNOPT
using SparseArrays

initialize("", "") do workspace
    set_option!(workspace, "Major print level", 0)

    n = 2
    rows = 1

    objective = x -> (x[1] - 1.0)^2 + (x[2] - 2.0)^2
    gradient! = (gradient, x) -> begin
        gradient[1] = 2.0 * (x[1] - 1.0)
        gradient[2] = 2.0 * (x[2] - 2.0)
        return nothing
    end

    objfun = make_objfun(objective, gradient!, workspace.iw)
    confun = make_dummy_confun()

    x = [0.0, 0.0, 0.0]
    lower = [-10.0, -10.0, -1.0e20]
    upper = [10.0, 10.0, 1.0e20]
    states = zeros(Int32, n + rows)
    J = SparseMatrixCSC{Float64, Int32}(
        1,
        n,
        Int32[1, 2, 2],
        Int32[1],
        [0.0],
    )

    problem = SnoptB(
        workspace,
        n,
        0,
        rows,
        n,
        x,
        lower,
        upper,
        states,
        J,
        0.0,
        0,
        Float64[],
        objfun,
        confun,
    )

    @assert snoptb!(problem) == 1
    @assert isapprox(problem.obj_val, 0.0; atol = 1.0e-8)
    @assert isapprox(problem.x[1:n], [1.0, 2.0]; atol = 1.0e-6)
end

# output
```

## Minimal `SnoptC` construction

`SnoptC` combines objective and constraint evaluation in one native callback.

```jldoctest snoptc
using SNOPT
using SparseArrays

initialize("", "") do workspace
    set_option!(workspace, "Major print level", 0)

    objective = x -> (x[1] - 2.0)^2
    gradient! = (gradient, x) -> (gradient[1] = 2.0 * (x[1] - 2.0))
    constraints! = (values, x) -> (values[1] = x[1])
    jacobian! = (nonzeros, x) -> (nonzeros[1] = 1.0)

    J = SparseMatrixCSC{Float64, Int32}(
        1, 1, Int32[1, 2], Int32[1], [0.0]
    )
    usrfun = make_usrfun_c(
        objective, gradient!, constraints!, jacobian!, J, workspace.iw
    )
    problem = SnoptC(
        workspace,
        1, 1, 1, 1,
        [0.0, 0.0],
        [-10.0, 1.0],
        [10.0, 1.0e20],
        zeros(Int32, 2),
        J,
        0.0,
        0,
        Float64[],
        usrfun,
    )

    @assert snoptc!(problem) == 1
    @assert isapprox(problem.obj_val, 0.0; atol = 1.0e-8)
    @assert isapprox(problem.x[1], 2.0; atol = 1.0e-6)
end

# output
```

Prefer [`snopt`](@ref) when it supports the problem. It provides validation,
automatic sizing, and simpler result handling.
