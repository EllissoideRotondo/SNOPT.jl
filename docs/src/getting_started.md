```@meta
CurrentModule = SNOPT
```

# Getting started

In this tutorial, we solve two small problems with [`snopt`](@ref), the simplest
entry point of SNOPT.jl. The first problem has only variable bounds; the second adds
nonlinear constraints and a sparse Jacobian. Both examples need a working SNOPT
library (see [Installation](installation.md)), and the second also uses the
`SparseArrays` standard library.

## Solve a problem with bounds

We want to minimize ``f(x) = (x_1 - 1)^2 + (x_2 - 2)^2`` subject to
``-10 \le x_i \le 10``. The solution is ``x = (1, 2)`` with ``f(x) = 0``.

SNOPT needs two functions: one that returns the objective value, and one that writes
the gradient into an array that SNOPT supplies. We define both and call `snopt`:

```jldoctest bounds
using SNOPT

objective(x) = (x[1] - 1.0)^2 + (x[2] - 2.0)^2

function gradient!(g, x)
    g[1] = 2.0 * (x[1] - 1.0)
    g[2] = 2.0 * (x[2] - 2.0)
    return nothing
end

x0 = [0.0, 0.0]
result = snopt(objective, gradient!, x0; lb = -10.0, ub = 10.0)
result.status

# output

SnoptStatus.Optimal = 1
```

The arguments of this call are:

- `objective(x)` returns the objective value as a real number.
- `gradient!(g, x)` writes ``\partial f / \partial x_i`` into `g[i]` for every `i`.
  SNOPT ignores its return value.
- `x0` is the starting point. Its length sets the number of variables.
- `lb` and `ub` are the variable bounds. A scalar applies to every variable; a vector
  gives one bound per variable. An omitted bound is infinite.

By default, `snopt` prints nothing and keeps no log file. To change tolerances or
limits, or to keep the SNOPT log, see [Set solver options](@ref).

## Read the result

[`snopt`](@ref) returns a [`SnoptResult`](@ref). We check the status first, because
`result.x` is meaningful only after a successful solve:

```jldoctest bounds
result.status == SnoptStatus.Optimal || error("SNOPT failed: $(result.status)")
round.(result.x; digits = 6)

# output

2-element Vector{Float64}:
 1.0
 2.0
```

| Field | Content |
| --- | --- |
| `status` | Outcome of the solve, a [`SnoptStatus`](@ref) value such as `SnoptStatus.Optimal`. `Int(result.status)` is the SNOPT status code. |
| `x` | Solution. |
| `objective` | Objective value at `x`. |
| `lambda` | Lagrange multipliers: one per variable, then one per constraint. |
| `major_itns` | Number of major iterations. |

[Solver concepts](@ref) lists all status codes. The [`SnoptResult`](@ref) docstring
lists all fields.

## Add nonlinear constraints

Next, we solve problem 71 of the Hock–Schittkowski test set, which has four
variables and two nonlinear constraints:

```math
\begin{aligned}
\min_{x} \quad & x_1 x_4 (x_1 + x_2 + x_3) + x_3 \\
\text{subject to} \quad & x_1 x_2 x_3 x_4 \ge 25, \\
& x_1^2 + x_2^2 + x_3^2 + x_4^2 = 40, \\
& 1 \le x_i \le 5, \quad i = 1, \dots, 4.
\end{aligned}
```

The optimal objective value is approximately ``17.014``.

A constrained problem needs four more keyword arguments:

| Keyword | Content |
| --- | --- |
| `eval_con` | `eval_con(c, x)` writes the constraint values into `c`. |
| `eval_jac` | `eval_jac(vals, x)` writes the Jacobian entries into `vals`. |
| `lcon` | Lower constraint bounds. Use `-Inf` for no lower bound. |
| `ucon` | Upper constraint bounds. Use `Inf` for no upper bound. |

Equal lower and upper bounds give an equality constraint. Here the first constraint
has `lcon = 25` and `ucon = Inf`, and the second has `lcon = ucon = 40`.

The Jacobian is the matrix ``J_{ij} = \partial c_i / \partial x_j``. We pass its
sparsity pattern, the positions of the entries that can be nonzero, as a sparse matrix
`J`; SNOPT.jl ignores the values stored in `J`. The function `eval_jac` must write the
entries in the order of `J.nzval`, which for a Julia `SparseMatrixCSC` is column by
column.

```jldoctest hs71
using SNOPT
using SparseArrays

objective(x) = x[1] * x[4] * (x[1] + x[2] + x[3]) + x[3]

function gradient!(g, x)
    g[1] = x[4] * (2.0 * x[1] + x[2] + x[3])
    g[2] = x[1] * x[4]
    g[3] = x[1] * x[4] + 1.0
    g[4] = x[1] * (x[1] + x[2] + x[3])
    return nothing
end

function constraints!(c, x)
    c[1] = x[1] * x[2] * x[3] * x[4]
    c[2] = x[1]^2 + x[2]^2 + x[3]^2 + x[4]^2
    return nothing
end

# Every entry of this 2×4 Jacobian can be nonzero.
J = sparse([1, 2, 1, 2, 1, 2, 1, 2], [1, 1, 2, 2, 3, 3, 4, 4], ones(8), 2, 4)

# Column order: (1,1), (2,1), (1,2), (2,2), (1,3), (2,3), (1,4), (2,4).
function jacobian!(vals, x)
    vals[1] = x[2] * x[3] * x[4]
    vals[2] = 2.0 * x[1]
    vals[3] = x[1] * x[3] * x[4]
    vals[4] = 2.0 * x[2]
    vals[5] = x[1] * x[2] * x[4]
    vals[6] = 2.0 * x[3]
    vals[7] = x[1] * x[2] * x[3]
    vals[8] = 2.0 * x[4]
    return nothing
end

result = snopt(objective, gradient!, [1.0, 5.0, 5.0, 1.0];
               lb = 1.0, ub = 5.0,
               eval_con = constraints!, eval_jac = jacobian!,
               lcon = [25.0, 40.0], ucon = [Inf, 40.0], J = J)
(result.status, round(result.objective; digits = 3))

# output

(SnoptStatus.Optimal, 17.014)
```

Without `J`, SNOPT.jl assumes that every Jacobian entry can be nonzero and orders the
entries column by column, as in this example. For large problems, pass `J`: SNOPT is
designed for sparse Jacobians, and a dense pattern makes each iteration slower.

!!! warning "Include every entry that can become nonzero"
    The sparsity pattern is fixed for the whole solve. Include an entry if it can be
    nonzero at any point, even if it is zero at `x0`. An entry that is missing from
    `J` is taken as zero, and SNOPT then works with a wrong Jacobian.

## Rules for the callback functions

These rules apply to `gradient!`, `eval_con` and `eval_jac`:

- Write every entry of the output array on every call.
- Do not change `x`.
- Do not keep a reference to `x` or to the output array after the function returns.
  SNOPT reuses their memory, so copy them to keep their values.
- Avoid memory allocation, because SNOPT calls these functions many times.

An error thrown inside a callback stops the solve. [`snopt`](@ref) closes its SNOPT
workspace and then throws the error again to the caller.

## Next steps

- Control tolerances, limits and output files: [Set solver options](@ref).
- Print progress or add a custom stopping rule: [Monitor and stop a solve](@ref).
- Solve a sequence of related problems faster: [Warm and hot starts](@ref).
- Let SNOPT estimate derivatives, or give linear constraints separately:
  [Low-level interface](@ref).

The repository contains both examples as scripts in `examples/`. Run them from the
repository root:

```bash
julia --project=. examples/unconstrained.jl
julia --project=. examples/hs71.jl
```

Each script writes the SNOPT log to a `.out` file next to the script.
