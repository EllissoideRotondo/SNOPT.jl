```@meta
CurrentModule = SNOPT
```

# Low-level interface

The low-level interface gives direct access to SNOPT's three solver interfaces,
`snOptA`, `snOptB` and `snOptC`. SNOPT.jl calls them through the C functions of
snopt-interface. The function [`snopt`](@ref) is a simpler front end to `snOptB`; the
low-level interface is necessary for these features:

- Finite-difference derivatives.
- Linear constraints, given separately from the nonlinear constraints.
- [Hot starts](@ref "Warm and hot starts").
- Options read from a specs file.

With the low-level interface, the caller creates the SNOPT workspace, builds the
problem arrays in the form that each SNOPT interface expects, and reads the results
from the problem object. SNOPT.jl
checks the array lengths, but it does not add the slack variables. It passes the
bounds to SNOPT without change and does not check them for `NaN`: use `±1.0e20`, not
`±Inf`, for an infinite bound.

| Problem type | SNOPT interface | User functions | Use for |
| --- | --- | --- | --- |
| [`SnoptA`](@ref) | `snOptA` | One function for all rows; derivatives optional | Linear rows, finite differences |
| [`SnoptB`](@ref) | `snOptB` | Separate objective and constraint functions | Control of the workspace and the start mode |
| [`SnoptC`](@ref) | `snOptC` | One function for objective and constraints | Shared work between objective and constraints |

[`snopt!`](@ref) solves any of the three types. [`snopta!`](@ref),
[`snoptb!`](@ref) and [`snoptc!`](@ref) solve one type each.

## Workspace

A workspace is the SNOPT session and its integer and real work arrays. Create it with
[`initialize`](@ref). The `do` form closes the workspace at the end of the block, also
after an error:

```julia
using SNOPT

initialize("", "") do workspace
    set_option!(workspace, "Major print level", 0)
    # Build and solve problems with this workspace.
end
```

The two string arguments are the paths of the print file and the summary file; `""`
writes no file. If you do not use the `do` form, call `close(workspace)` when you are
done.

Only one workspace can be open in a Julia process, and [`initialize`](@ref) closes
the previous workspace. [Solver concepts](@ref) explains this limit.

### Workspace size

The default workspace has 30500 integer and 60000 real entries. A larger problem
needs more. [`snmemb`](@ref) asks SNOPT for the minimum sizes of an `snOptB` or
`snOptC` problem:

```julia
memory = snmemb(m, n, neJ, negCon, nnCon, nnObj, nnJac)
initialize("", "", memory.miniw, memory.minrw) do workspace
    # ...
end
```

| Argument | Meaning |
| --- | --- |
| `m` | Number of constraint rows (at least 1). |
| `n` | Number of variables. |
| `neJ` | Number of entries in the Jacobian sparsity pattern. |
| `negCon` | Number of those entries that belong to nonlinear constraints. |
| `nnCon` | Number of nonlinear constraints. |
| `nnObj` | Number of variables that appear nonlinearly in the objective. |
| `nnJac` | Number of variables that appear nonlinearly in the constraints. |

SNOPT requires that the nonlinear variables come first in `x`: the objective is
nonlinear in `x[1:nnObj]` only, and the constraints in `x[1:nnJac]` only. Each work
array must have at least 500 entries. For an [`SnoptA`](@ref) problem, there is no
sizing function: if the solve ends with a status from 81 to 84, open a larger
workspace.

## Options

[`set_option!`](@ref) sets one option on an open workspace:

```julia
set_option!(workspace, "Major iterations limit", 250)
set_option!(workspace, "Major optimality tolerance", 1.0e-8)
set_option!(workspace, "Hessian limited memory")
```

The option names are the same as in [Set solver options](@ref).
[`read_options`](@ref) reads a specs file, as that page also describes.

## `SnoptA`: finite differences, linear rows and hot starts

[`SnoptA`](@ref) puts the objective and all constraints in one vector ``F(x)`` of `nf`
rows. Row `objrow` is the objective; the other rows are constraints with bounds
`flow ≤ F ≤ fupp`. The derivatives of ``F`` come in two parts, both as lists of
(row, column) positions:

- The linear part: constant entries `A[k]` at position `(iAfun[k], jAvar[k])`.
- The nonlinear part: positions `(iGfun[k], jGvar[k])` whose values the user function
  computes.

This example minimizes ``(x_1 - 2)^2`` without derivatives, so SNOPT estimates them by
finite differences. It then changes the starting point and solves again with a hot
start.

```jldoctest snopta
julia> using SNOPT

julia> initialize("", "") do workspace
           set_option!(workspace, "Derivative option", 0)  # finite differences
           usrfun = make_usrfun_a((F, x) -> (F[1] = (x[1] - 2.0)^2))
           problem = SnoptA(workspace,
                            1, 1,                     # nf, n
                            0.0, 1,                   # objadd, objrow
                            Int32[], Int32[], Float64[],   # iAfun, jAvar, A: no linear part
                            Int32[1], Int32[1],       # iGfun, jGvar: F[1] depends on x[1]
                            [-10.0], [10.0],          # xlow, xupp
                            [-1.0e20], [1.0e20],      # flow, fupp: objective row free
                            [0.0], zeros(Int32, 1), zeros(1),   # x, xstate, xmul
                            zeros(1), zeros(Int32, 1), zeros(1), # F, Fstate, Fmul
                            0, 0, 0, 0.0,             # status, nS, num_inf, sum_inf
                            usrfun)
           status1 = snopta!(problem)
           problem.x[1] = 2.1                         # new starting point
           status2 = snopta!(problem; start = "Hot")
           (status1, status2, round(problem.x[1]; digits = 4))
       end
(1, 1, 2.0)
```

[`snopta!`](@ref) returns the SNOPT status code (here `1`, optimal solution found).
It writes the solution into `problem.x`, the row values into `problem.F`, and the
multipliers into `problem.xmul` and `problem.Fmul`.

The option `"Derivative option"` tells SNOPT which derivatives the user function gives: `1`, the
default, means all of them, and `0` means that SNOPT estimates the missing ones. To
give derivatives, pass `eval_G` to [`make_usrfun_a`](@ref): `eval_G(G, x)` writes the
value at position `(iGfun[k], jGvar[k])` into `G[k]`.

## `SnoptB`: separate objective and constraint functions

[`SnoptB`](@ref) is the type that [`snopt`](@ref) builds internally. All its
constraints are nonlinear, and SNOPT.jl takes the constraints as nonlinear in all
`n` variables (`nnJac = n`). The arrays `x`, `bl`, `bu` and `hs` have length
`n + m_eff`: the `n` variables first, then one
[slack variable](@ref "Slack variables") for each of the `m_eff` constraint rows. A
problem without constraints still needs one row with infinite bounds, so
`m_eff = 1`, and this row must be included in the arrays.
Its Jacobian pattern `J` is a `1 × n` matrix with one entry, because SNOPT needs at
least one. `J` must have the type `SparseMatrixCSC{Float64, Int32}`; `sparse` gives
this type when the index vectors are `Int32`.

```jldoctest snoptb
julia> using SNOPT

julia> using SparseArrays

julia> initialize("", "") do workspace
           n, m_eff = 2, 1
           objective(x) = (x[1] - 1.0)^2 + (x[2] - 2.0)^2
           function gradient!(g, x)
               g[1] = 2.0 * (x[1] - 1.0)
               g[2] = 2.0 * (x[2] - 2.0)
               return nothing
           end
           objfun = make_objfun(objective, gradient!, workspace.iw)
           confun = make_dummy_confun()                   # no constraints
           J = sparse(Int32[1], Int32[1], [0.0], m_eff, n)  # one entry at (1, 1)
           problem = SnoptB(workspace,
                            n, 0, m_eff, n,              # n, nc, m_eff, nnobj
                            zeros(n + m_eff),            # x
                            [-10.0, -10.0, -1.0e20],     # bl
                            [10.0, 10.0, 1.0e20],        # bu
                            zeros(Int32, n + m_eff),     # hs
                            J,
                            0.0, 0, Float64[],           # obj_val, status, lambda
                            objfun, confun)
           status = snoptb!(problem)
           (status, round.(problem.x[1:n]; digits = 4))
       end
(1, [1.0, 2.0])
```

After the solve, `problem.x`, `problem.obj_val`, `problem.lambda` and `problem.hs`
contain the result.

## `SnoptC`: one function for objective and constraints

[`SnoptC`](@ref) has the same arrays as [`SnoptB`](@ref), but SNOPT calls one
function for the objective and the constraints. [`make_usrfun_c`](@ref) builds this
function from the same four Julia functions that [`snopt`](@ref) uses. This example
minimizes ``(x_1 - 2)^2`` subject to ``x_1 \ge 1``:

```jldoctest snoptc
julia> using SNOPT

julia> using SparseArrays

julia> initialize("", "") do workspace
           objective(x) = (x[1] - 2.0)^2
           gradient!(g, x) = (g[1] = 2.0 * (x[1] - 2.0))
           constraints!(c, x) = (c[1] = x[1])
           jacobian!(vals, x) = (vals[1] = 1.0)
           J = sparse(Int32[1], Int32[1], [1.0], 1, 1)
           usrfun = make_usrfun_c(objective, gradient!, constraints!, jacobian!, J,
                                  workspace.iw)
           problem = SnoptC(workspace,
                            1, 1, 1, 1,                  # n, nc, m_eff, nnobj
                            [0.0, 0.0],                  # x
                            [-10.0, 1.0],                # bl: variable, then constraint
                            [10.0, 1.0e20],              # bu
                            zeros(Int32, 2),             # hs
                            J,
                            0.0, 0, Float64[],           # obj_val, status, lambda
                            usrfun)
           status = snoptc!(problem)
           (status, round(problem.x[1]; digits = 4))
       end
(1, 2.0)
```

## Callback builders

SNOPT calls C functions with a fixed argument list. The builders wrap Julia
functions in functions of that form:

| Builder | User functions | Used by |
| --- | --- | --- |
| [`make_objfun`](@ref) | `eval_obj(x)`, `eval_grad(g, x)` | [`SnoptB`](@ref) |
| [`make_confun`](@ref) | `eval_con(c, x)`, `eval_jac(vals, x)` | [`SnoptB`](@ref) |
| [`make_dummy_confun`](@ref) | none (no constraints) | [`SnoptB`](@ref) |
| [`make_usrfun_c`](@ref) | all four of the above | [`SnoptC`](@ref) |
| [`make_usrfun_a`](@ref) | `eval_F(F, x)`, optional `eval_G(G, x)` | [`SnoptA`](@ref) |

The user functions follow the [rules for callback functions](@ref "Rules for the callback functions").
Each builder accepts the keyword `callback`, which is called after each evaluation
and stops the solve if it returns `false`, as in [Monitor and stop a solve](@ref).
The fields of its `NamedTuple` argument depend on the builder; the docstring of each
builder lists them. To pass `snlog` or `snstop`, give them as keywords
to the solve function, for example `snoptb!(problem; snlog = f)`.
