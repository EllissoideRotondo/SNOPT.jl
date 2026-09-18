```@meta
CurrentModule = SNOPT
```

# High-level interface

[`snopt`](@ref) is the recommended entry point. It builds a [`SnoptB`](@ref)
problem and sizes its workspace. It always closes the workspace after solving.

```julia
result = snopt(eval_obj, eval_grad, x0; kwargs...)
```

## Required callbacks

| Argument | Contract |
| --- | --- |
| `eval_obj` | `eval_obj(x) -> Real` returns the objective. |
| `eval_grad` | `eval_grad(gradient, x)` fills every gradient entry. |
| `x0` | Finite starting point with at least one variable. |

Let `n = length(x0)`. Both `x` and `gradient` have length `n`.
Treat `x` as read-only. The gradient callback may return any value; SNOPT uses the mutated array.
SNOPT.jl copies `x0` and bounds, and uses `Float64` arrays internally.
Copy callback arrays before retaining them; SNOPT reuses their storage.

```julia
using SNOPT

objective(x) = (x[1] - 1.0)^2 + (x[2] - 2.0)^2

function gradient!(gradient, x)
    gradient[1] = 2.0 * (x[1] - 1.0)
    gradient[2] = 2.0 * (x[2] - 2.0)
    return nothing
end

x0 = [0.0, 0.0]
result = snopt(objective, gradient!, x0)
```

The high-level interface requires derivatives. Use [`SnoptA`](@ref) when SNOPT
must estimate derivatives with finite differences.

## Variable bounds

`lb` and `ub` set lower and upper variable bounds. Each value may be a scalar
or a vector of length `length(x0)`.

Omitted bounds are infinite. SNOPT.jl represents `Inf` and `-Inf` as `1.0e20` and `-1.0e20`.

```julia
result = snopt(
    objective,
    gradient!,
    x0;
    lb = [0.0, -1.0],
    ub = 5.0,
)
```

Bounds cannot contain `NaN`.

## Nonlinear constraints

Provide all four required constraint arguments together.

| Argument | Contract |
| --- | --- |
| `eval_con` | `eval_con(values, x)` fills every constraint value. |
| `eval_jac` | `eval_jac(nonzeros, x)` fills every stored derivative. |
| `lcon` | Constraint lower bounds. |
| `ucon` | Constraint upper bounds with the same length. |

Let `m = length(lcon)`. Both constraint bounds must be vectors of length `m`.
`values` has length `m`. Constraint bounds cannot contain `NaN`.

`J` may provide the sparse Jacobian structure, with shape `(m, n)`.
A Jacobian is the matrix of constraint derivatives.
SNOPT.jl uses a dense structure when `J` is omitted.

`eval_jac` must follow `J.nzval` order. Julia sparse matrices store those values
by column. The numeric values initially stored in `J` are ignored.
The `nonzeros` array has length `nnz(J)`, or `m * n` when `J` is omitted.
Include every derivative that can become nonzero, even if it is zero at `x0`.

```julia
using SparseArrays

function constraints!(values, x)
    values[1] = x[1] * x[2]
    values[2] = x[1]^2 + x[2]^2
    return nothing
end

function jacobian!(nonzeros, x)
    nonzeros[1] = x[2]
    nonzeros[2] = 2.0 * x[1]
    nonzeros[3] = x[1]
    nonzeros[4] = 2.0 * x[2]
    return nothing
end

J = sparse(
    [1, 2, 1, 2],
    [1, 1, 2, 2],
    ones(4),
    2,
    2,
)

result = snopt(
    objective,
    gradient!,
    [1.0, 1.0];
    eval_con = constraints!,
    eval_jac = jacobian!,
    lcon = [1.0, 2.0],
    ucon = [Inf, 2.0],
    J,
)
```

Equal lower and upper bounds create an equality constraint. An infinite bound
creates a one-sided constraint.

## Derivative conventions

- Treat callback input `x` as read-only.
- Fill every requested gradient or Jacobian entry in place.
- The objective gradient has `length(x0)` entries.
- Keep the Jacobian structure fixed during a solve.
- Fill `eval_jac` output in the order of `J.nzval`.
- Include every entry that can become nonzero during the solve.
- The numeric values initially stored in `J.nzval` are ignored.
- Avoid allocations in callbacks that SNOPT calls repeatedly.

## SNOPT options

Pass `options` as a vector of pairs. Keys may be strings or symbols.
Underscores in symbol keys become spaces.

```julia
options = [
    "Major print level" => 0,
    :major_iterations_limit => 500,
    :hessian => :limited_memory,
]
```

Values may be integers, finite floats, strings, or symbols. Boolean values are
rejected because Julia treats them as integers.

The low-level [`read_options`](@ref) function loads a SNOPT specs file into an open workspace.
A specs file is a text file of native solver settings. See the
[SNOPT option reference](https://ccom.ucsd.edu/~optimizers/docs/snopt/options.html)
for all native settings.

## Monitoring and stopping

Three callbacks expose different solver events.

| Callback | Frequency | Event |
| --- | --- | --- |
| `snlog` | Once per major iteration | [`SnoptMajorLog`](@ref) |
| `snstop` | Once per major iteration | [`SnoptStopEvent`](@ref) |
| `callback` | Every objective or constraint evaluation | `NamedTuple` |

Major iterations update the nonlinear problem. Minor iterations solve each quadratic subproblem.

Return `false` from any callback to request termination. Return any other value
to continue.

Evaluation events contain `kind`, `mode`, `major_iter`, `minor_iter`, and a copy of `x`.
Objective events add `f`; constraint events add `c`.
They also occur during the initial callback check, before solver iterations begin.
Errors thrown by callbacks propagate to the caller after workspace cleanup.

Use `snlog` for progress output. Use `snstop` for custom stopping rules.
Use `callback` only when evaluation-level events are needed.

```julia
deadline = time() + 30.0

result = snopt(
    objective,
    gradient!,
    x0;
    snlog = event -> begin
        println("major $(event.major_iter): $(event.objective)")
        return true
    end,
    snstop = event -> time() < deadline,
)
```

The result uses a `:User_Requested_Stop` status after an accepted stop request.

### Major-iteration fields

[`SnoptMajorLog`](@ref) contains the fields below. Scalar convergence measures
use SNOPT's scaled problem unless stated otherwise.

| Field | Meaning | Unit or length |
| --- | --- | --- |
| `iteration`, `major_iter`, `minor_iter` | Solver iteration counters | Count |
| `n_superbasics`, `n_swaps` | Current superbasic variables and basis swaps | Count |
| `objective`, `merit` | Objective and merit values | Problem units |
| `f_objective`, `f_merit` | Nonlinear parts of the objective and merit | Problem units |
| `primal_infeasibility`, `dual_infeasibility` | Convergence measures | Scaled |
| `max_violation`, `relative_violation` | Largest constraint violation | Scaled |
| `step`, `penalty_norm`, `condition_hessian` | Current algorithm state | SNOPT internal scale |
| `objective_scale`, `objective_add` | Objective scale and constant offset | SNOPT internal scale, problem units |
| `minimize`, `kt_conditions` | Objective direction and termination tests | Flag values |
| `n`, `nb`, `nncon`, `nnobj` | Current problem dimensions | Count |
| `x` | Variables followed by slacks | `nb` |
| `fcon`, `fx` | Constraint and row values | `nncon` |
| `ycon` | Constraint multipliers | `nncon` |
| `hs` | Basis states | `nb` |

[`SnoptStopEvent`](@ref) includes these fields and the additional arrays below.

| Field | Meaning | Length |
| --- | --- | --- |
| `m`, `max_superbasics`, `negcon` | Additional problem dimensions | Scalar counts |
| `gobj` | Objective gradient | `nnobj` |
| `gcon` | Stored constraint Jacobian values | `negcon` |
| `pi` | Row multipliers | `m` |
| `rc` | Reduced costs for variables and slacks | `nb` |
| `rg` | Reduced gradient for superbasic variables | `max_superbasics` |
| `bl`, `bu` | Scaled lower and upper bounds | `nb` |

## Output files

| Keyword | Default | Meaning |
| --- | --- | --- |
| `printfile` | `""` | Detailed SNOPT output path. |
| `summfile` | `""` | Summary output path. |
| `name` | `"Julia"` | Problem name with at most eight bytes. |

Empty output paths suppress visible files. SNOPT.jl may create a temporary
summary file internally. The workspace removes that file when it closes.

## Warm starts

A warm start reuses a basis from a related solve. A basis records which bounds
and rows were active at the previous solution.

```julia
first = snopt(objective, gradient!, x0)
second = snopt(
    objective,
    gradient!,
    first.x;
    start = "Warm",
    basis = first.basis,
)
```

The basis dimensions must match the new problem. `start = "Warm"` requires a
basis. A cold start rejects an unused basis.

The high-level function rejects `start = "Hot"`. Hot starts require state from
the same workspace. Use the [Low-level interface](@ref) and reuse one workspace.

## Result fields

[`snopt`](@ref) returns a [`SnoptResult`](@ref).

| Field | Meaning |
| --- | --- |
| `status` | SNOPT integer result code. |
| `status_symbol` | Symbol from [`SNOPT_STATUS`](@ref). |
| `objective` | Final objective value. |
| `x` | Final design variables. |
| `lambda` | Variable multipliers followed by constraint multipliers. |
| `num_inf` | Number of remaining infeasibilities. |
| `sum_inf` | Sum of remaining infeasibilities. |
| `iterations` | Total minor iterations. |
| `major_itns` | Total major iterations. |
| `run_time` | SNOPT-reported CPU solve time in seconds. |
| `memory` | Workspace estimate used by the solve. |
| `basis` | Basis for a later warm start. |

`basis` is meaningful only after SNOPT starts. A callback can stop during the
initial evaluation, before a valid basis exists.

## Termination status

Check both `result.status` and `result.status_symbol`. The integer is SNOPT's
native `INFO` code, while the symbol groups related codes for program logic.

| Code family | Category | Typical `status_symbol` |
| --- | --- | --- |
| 1--6 | Successful or acceptable result | `:Solve_Succeeded`, `:Feasible_Point_Found`, `:Solved_To_Acceptable_Level` |
| 11--16 | Infeasible problem | `:Infeasible_Problem_Detected` |
| 21--22 | Unbounded problem | `:Unbounded_Problem_Detected` |
| 31--34 | Iteration, time, or superbasics limit | `:Maximum_Iterations_Exceeded`, `:Maximum_CpuTime_Exceeded` |
| 41--45 | Numerical difficulty | `:Numerical_Difficulties` |
| 51--63 | Callback error or undefined callback value | `:User_Supplied_Function_Error`, `:User_Supplied_Function_Undefined` |
| 71--74 | User stop | `:User_Requested_Stop` |
| 81--84 | Insufficient memory | `:Insufficient_Memory` |
| 91--92 | Invalid problem definition | `:Invalid_Problem_Definition` |

See the [SNOPT 7.7 exit conditions](https://ccom.ucsd.edu/~optimizers/static/pdfs/sndoc7.pdf#page=110)
for the meaning of each native code.
