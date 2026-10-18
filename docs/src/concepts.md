```@meta
CurrentModule = SNOPT
```

# Solver concepts

This page explains the SNOPT terms that appear in the results, the options and the
callback arguments of SNOPT.jl, and the rules that come from the design of the SNOPT
library. The [SNOPT 7.7 user guide](https://ccom.ucsd.edu/~optimizers/static/pdfs/sndoc7.pdf)
gives the full description.

## Major and minor iterations

SNOPT uses a sequential quadratic programming (SQP) method. At each *major
iteration*, it replaces the problem near the current point by a quadratic program
(QP), in which the objective is quadratic and the constraints are linear, and the
solution of this QP gives the search direction for the next point. SNOPT solves each
QP with an iterative method whose steps are the *minor iterations*, so one major
iteration usually contains several minor iterations.

SNOPT does not need second derivatives: it builds an approximation of the Hessian of
the Lagrangian from the change in the gradients between major iterations. This is
the reason why SNOPT.jl asks only for first derivatives. For problems with many variables,
the option `"Hessian" => "limited memory"` keeps only a few recent updates instead of
a full matrix.

The options `"Major iterations limit"` and `"Iterations limit"` limit the two kinds of
iteration, and [`SnoptResult`](@ref) reports both counts in `major_itns` and
`iterations`.

## Slack variables

SNOPT turns each constraint row ``l_i \le c_i(x) \le u_i`` into an equation
``c_i(x) - s_i = 0`` with a bounded *slack variable* ``l_i \le s_i \le u_i``. After
this change, every inequality is a bound on a variable, and the SNOPT method handles
bounds directly. For this reason, several arrays in SNOPT.jl have length
``n + m``, with the ``n`` variables first and the ``m`` slack variables after them:
for example `x` in [`SnoptMajorLog`](@ref) and the arrays of the low-level problem
types.

SNOPT needs at least one constraint row. When a problem has no constraints,
[`snopt`](@ref) adds one row with infinite bounds, so ``m = 1`` in the arrays above;
in the low-level problem types, the caller adds this row.

## Basis, superbasic variables and warm starts

At each point, SNOPT divides the variables, including the slack variables, into
three groups: *nonbasic* variables, which are fixed at their lower or upper bound;
*basic* variables, which the linearized constraints determine from the others; and
*superbasic* variables, which are free to move between their bounds. SNOPT changes
only the superbasic variables directly, so their number is the dimension of the space
in which SNOPT searches for a better point. This division is the *basis*, and SNOPT records it
in an integer state for each variable:

| State | Meaning |
| --- | --- |
| `0` | Nonbasic, at the lower bound. |
| `1` | Nonbasic, at the upper bound. |
| `2` | Superbasic. |
| `3` | Basic. |

A [`SnoptBasis`](@ref) stores these states, as `hs`, together with the number of
superbasic variables `nS`. In a *warm start*, SNOPT begins with a stored basis instead
of constructing a new basis, which saves work when the new problem is close to the
old one. A *hot start* goes further and also reuses the LU factorization of the basis
matrix and the Hessian approximation inside the SNOPT workspace; [Warm and hot starts](@ref) shows
how to use both.

## Infinite bounds

SNOPT treats any bound with absolute value of at least ``10^{20}`` as infinite. The
function [`snopt`](@ref) converts `Inf` and `-Inf` to `1.0e20` and `-1.0e20`, so
either form works there. The low-level problem types pass the arrays to SNOPT without
change and check only their lengths, so they need `±1.0e20` for an infinite bound.
[`snopt`](@ref) rejects a `NaN` bound; the low-level types do not check for it.

## Status codes

When a solve ends, SNOPT returns an integer status code. SNOPT.jl stores this code in
`result.status`, and it stores in `result.status_symbol` a symbol that names the group
of related codes, taken from the dictionary [`SNOPT_STATUS`](@ref). Program logic
should test the symbol; the integer gives the exact reason, and the
[SNOPT 7.7 user guide](https://ccom.ucsd.edu/~optimizers/static/pdfs/sndoc7.pdf#page=110)
explains each code.

| Code | `status_symbol` | Meaning |
| --- | --- | --- |
| 1 | `:Solve_Succeeded` | Optimal solution found. |
| 2 | `:Feasible_Point_Found` | Feasible point found (the objective was not optimized). |
| 3–6 | `:Solved_To_Acceptable_Level` | Partial success, for example the requested accuracy was not reached. Check the exact code. |
| 11–16 | `:Infeasible_Problem_Detected` | The constraints cannot be satisfied. |
| 21–22 | `:Unbounded_Problem_Detected` | The objective decreases without limit. |
| 31–32 | `:Maximum_Iterations_Exceeded` | An iteration limit was reached. |
| 33 | `:Superbasics_Limit_Too_Small` | The option `"Superbasics limit"` is too small. |
| 34 | `:Maximum_CpuTime_Exceeded` | The CPU time limit (option `"Time limit"`) was reached. |
| 41–45 | `:Numerical_Difficulties` | SNOPT could not continue for numerical reasons. |
| 51–52, 56 | `:User_Supplied_Function_Error` | The derivatives appear to be wrong, or the functions are badly scaled. |
| 61–63 | `:User_Supplied_Function_Undefined` | A function could not be evaluated at a point. |
| 71–74 | `:User_Requested_Stop` | A callback function returned `false`. |
| 81–84 | `:Insufficient_Memory` | The SNOPT workspace is too small. |
| 91–92 | `:Invalid_Problem_Definition` | The problem data are not valid. |
| 141–142, 999 | `:Internal_Error` | Error inside SNOPT. |

A code that is not in [`SNOPT_STATUS`](@ref) gives `:Unknown_Status`.

## One SNOPT workspace per Julia process

The SNOPT library allows only one active session in each process. SNOPT.jl calls
this session, together with its integer and real work arrays, the workspace. SNOPT.jl therefore runs solves one at a time: when several tasks or threads call
[`snopt`](@ref) at the same time, each call waits until the previous call has
finished. To solve several problems in parallel, start several Julia processes, for
example with the `Distributed` standard library, because each process loads its own
copy of the library.

With the [Low-level interface](@ref), the caller creates the workspace with
[`initialize`](@ref). Each call to [`initialize`](@ref), [`snopt`](@ref) or
[`snmemb`](@ref) waits for a running solve to end, then opens a new workspace and
closes the workspace that was open before. For this reason, none of them may be
called while a low-level workspace is still in use. Manage a low-level workspace from one task only. Do not call any
SNOPT.jl function that uses the workspace from inside a callback function while a
solve is running: such a call throws an `ArgumentError`.

## Limits

- [`snopt`](@ref) needs exact first derivatives. To let SNOPT estimate derivatives by
  finite differences, use [`SnoptA`](@ref).
- [`snopt`](@ref) treats all constraints as nonlinear. To give linear constraints
  separately, use [`SnoptA`](@ref).
- [`snopt`](@ref) does not support hot starts and does not read specs files.
- The variables and the bounds are converted to `Float64`.
- Iteration counts and solve times are correct only with SNOPT 7.7.
