```@meta
CurrentModule = SNOPT
```

# Warm and hot starts

When you solve a sequence of related problems, for example the same model with
slightly different parameters, you can start each solve from the end state of the
previous one. SNOPT then often needs fewer iterations. SNOPT has three start modes:

| Mode | Starts from | Available in |
| --- | --- | --- |
| Cold | The point `x0` only. This is the default. | [`snopt`](@ref) and the low-level interface |
| Warm | `x0` and the basis of a previous solve. | [`snopt`](@ref) and the low-level interface |
| Hot | `x0`, the basis, the basis factorization and the Hessian approximation of a previous solve. | Low-level interface only |

The basis records which variables and constraints were at a bound at the end of a
solve. [Solver concepts](@ref) explains it in more detail.

## Warm start with `snopt`

Pass the `basis` of the previous [`SnoptResult`](@ref) and `start = "Warm"`. Usually
you also start from the previous solution:

```julia
lb, ub = -10.0, 10.0
result1 = snopt(objective, gradient!, x0; lb = lb, ub = ub)

result2 = snopt(objective, gradient!, result1.x; lb = lb, ub = ub,
                start = "Warm", basis = result1.basis)
```

The two problems must have the same number of variables and the same number of
constraints. The functions and the bounds can be different.

[`snopt`](@ref) throws an `ArgumentError` in these cases:

- `start = "Warm"` without `basis`.
- `basis` without `start = "Warm"`.
- A `basis` from a problem with a different size.

If a solve stopped during the first evaluations, before SNOPT started (see
[Monitor and stop a solve](@ref)), its basis contains no information. A warm start
from it is then the same as a cold start.

## Hot start

A hot start also reuses the LU factorization of the basis matrix and the Hessian
approximation that SNOPT keeps in its workspace. These exist only in the workspace
of the previous solve. [`snopt`](@ref) creates a new workspace for each call, so it
rejects `start = "Hot"`.

To use a hot start:

1. Open one workspace with [`initialize`](@ref) and build a low-level problem.
2. Solve the problem.
3. Change values in the same problem object, for example the starting point `x`.
   Do not change the sizes or the sparsity pattern.
4. Solve again with `start = "Hot"`, before you close the workspace.

The [`SnoptA` example](@ref "SnoptA: finite differences, linear rows and hot starts")
in the low-level interface does these steps.
