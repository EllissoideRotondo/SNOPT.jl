```@meta
CurrentModule = SNOPT
```

# Monitor and stop a solve

[`snopt`](@ref) accepts three optional functions that SNOPT.jl calls during the
solve. Each function receives one argument that describes the current state. If a
function returns `false`, SNOPT stops the solve; any other return value lets the solve
continue.

| Keyword | Called | Argument |
| --- | --- | --- |
| `snlog` | Once per major iteration | [`SnoptMajorLog`](@ref) |
| `snstop` | Once per major iteration | [`SnoptStopEvent`](@ref) |
| `callback` | After each evaluation of the objective or the constraints | `NamedTuple` |

Use `snlog` to print or record progress. Use `snstop` for a stopping rule that needs
gradients or multipliers. Use `callback` only when you need every function evaluation:
SNOPT evaluates the functions several times per major iteration, so this function is
called much more often.

## Print progress

```julia
result = snopt(objective, gradient!, x0;
               snlog = function (event)
                   println("iteration ", event.major_iter,
                           ": f = ", event.objective,
                           ", infeasibility = ", event.primal_infeasibility)
                   return true
               end)
```

The most useful fields of [`SnoptMajorLog`](@ref) are:

| Field | Content |
| --- | --- |
| `major_iter` | Number of the current major iteration. |
| `objective` | Current objective value. |
| `primal_infeasibility` | Constraint violation, scaled. |
| `dual_infeasibility` | Error in the optimality conditions, scaled. |
| `x` | Current variables, followed by one slack variable per constraint. |

The docstring of [`SnoptMajorLog`](@ref) lists all fields. SNOPT can scale the
variables and the constraints to improve the numerical behaviour (option
`"Scale option"`), and it computes the two infeasibility values for the scaled
problem. They decrease to the tolerances in [Set solver options](@ref) as the solve
converges.

## Stop on a custom condition

This example stops the solve after 30 seconds of wall-clock time:

```julia
deadline = time() + 30.0
result = snopt(objective, gradient!, x0;
               snstop = event -> time() < deadline)
result.status_symbol   # :User_Requested_Stop if the deadline was reached
```

When a function returns `false`, the result has the status
`:User_Requested_Stop`, and `result.x` is the point at which SNOPT stopped.
To limit only the number of iterations or the CPU time, use the options
`"Major iterations limit"` or `"Time limit"` instead. The option `"Time limit"`
measures CPU time, so use `snstop` to stop on wall-clock time, as in this example.

[`SnoptStopEvent`](@ref) has all the fields of [`SnoptMajorLog`](@ref), and also the
objective gradient `gobj`, the Jacobian values `gcon`, the multipliers `pi` and the
scaled bounds `bl` and `bu`.

## Observe each function evaluation

For [`snopt`](@ref), the `callback` function receives a `NamedTuple` with these
fields. The callback builders of the [Low-level interface](@ref) use other `kind`
values and fields; their docstrings list them.

| Field | Content |
| --- | --- |
| `kind` | `:objective` or `:constraint`. |
| `mode` | `0` if SNOPT asked for the value only, `2` if it also asked for derivatives. |
| `major_iter`, `minor_iter` | Always `0` in this version. Use `snlog` for iteration counts. |
| `x` | Copy of the point. |
| `f` | Objective value. Only when `kind == :objective`. |
| `c` | Copy of the constraint values. Only when `kind == :constraint`. |

Before SNOPT starts, SNOPT.jl evaluates each function once at `x0`, with each entry
clamped to its bounds `[lb, ub]`. This finds errors in the user functions early.
`callback` is also called for these first evaluations.

If `callback` returns `false` during these first evaluations, SNOPT does not start.
The result then has the status `:User_Requested_Stop`, and `result.basis` contains
no information: a [warm start](@ref "Warm and hot starts") from it is the same as a
cold start.
