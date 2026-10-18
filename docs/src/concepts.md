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

When a solve ends, SNOPT returns an integer status code. SNOPT.jl stores it in
`result.status` as a value of the enum [`SnoptStatus`](@ref), whose integer value is the
code itself: `Int(result.status)` gives the code, and `SnoptStatus.T(code)` gives the
value. Program logic tests the value, for example
`result.status == SnoptStatus.Optimal`; a misspelt name then fails with an
`UndefVarError` instead of comparing as `false`. The tens digit of a code is its group,
so `Int(result.status) ÷ 10 == 1` holds for every infeasible outcome. The
[SNOPT 7.7 user guide](https://ccom.ucsd.edu/~optimizers/static/pdfs/sndoc7.pdf#page=110)
explains each code.

| Codes | `SnoptStatus` values | Meaning |
| --- | --- | --- |
| 1 | `Optimal` | Optimal solution found. |
| 2 | `FeasiblePoint` | Feasible point found; the objective was not optimized (option `"Feasible point only"`). |
| 3 | `AccuracyNotAchieved` | The requested accuracy could not be achieved. |
| 5–6 | `ElasticObjectiveMinimized`, `ElasticInfeasibilitiesMinimized` | Results of SNOPT's elastic mode, which relaxes the constraints marked as elastic. |
| 11–16 | `InfeasibleLinear`, `InfeasibleLinearEqualities`, `NonlinearInfeasibilitiesMinimized`, `LinearInfeasibilitiesMinimized`, `InfeasibleQPSubproblem`, `InfeasibleNonelastic` | The constraints cannot be satisfied. |
| 21–22 | `UnboundedObjective`, `ConstraintViolationLimit` | The objective decreases without limit, or the constraint violation limit was reached. |
| 31–32 | `IterationLimit`, `MajorIterationLimit` | The minor or the major iteration limit was reached. |
| 33 | `SuperbasicsLimit` | The option `"Superbasics limit"` is too small. |
| 34 | `TimeLimit` | The CPU time limit (option `"Time limit"`) was reached. |
| 41–45 | `CannotImprove`, `SingularBasis`, `CannotSatisfyConstraints`, `IllConditionedNullSpace`, `LUFactorizationFailed` | SNOPT could not continue for numerical reasons. |
| 51, 52, 56 | `IncorrectObjectiveDerivatives`, `IncorrectConstraintDerivatives`, `BadlyScaledFunctions` | The derivatives appear to be wrong, or the functions are badly scaled. |
| 61–63 | `UndefinedAtFirstFeasiblePoint`, `UndefinedAtInitialPoint`, `UndefinedRegion` | A function could not be evaluated at a point. |
| 71–74 | `StopInFunction`, `StopInConstraints`, `StopInObjective`, `StopInMonitor` | A user function returned `false`. |
| 81–84 | `WorkArraysTooSmall`, `CharacterStorage`, `IntegerStorage`, `RealStorage` | The SNOPT workspace is too small. |
| 91–92 | `InvalidInput`, `BasisFileMismatch` | The problem data or the basis file are not valid. |
| 141–142 | `WrongBasicVariableCount`, `BasisPackageError` | Error inside SNOPT. |
| any other | `Unknown` (`0`) | A code that the SNOPT 7.7 user guide does not list. |

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
