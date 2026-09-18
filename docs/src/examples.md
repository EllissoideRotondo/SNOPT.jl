```@meta
CurrentModule = SNOPT
```

# Examples

Run both scripts from the SNOPT.jl repository root:

```bash
julia --project=. examples/unconstrained.jl
julia --project=. examples/hs71.jl
```

Both commands require a working licensed SNOPT library.
Each script writes a solver log beside the script: `unconstrained.out` or `hs71.out`.
The examples below suppress those files by omitting `printfile`.

## Unconstrained quadratic

This problem minimizes ``(x_1 - 1)^2 + (x_2 - 2)^2``. Its solution is
``x = (1, 2)`` with objective zero.

```jldoctest unconstrained
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

@assert result.status_symbol == :Solve_Succeeded
@assert isapprox(result.objective, 0.0; atol = 1.0e-8)
@assert isapprox(result.x, [1.0, 2.0]; atol = 1.0e-6)

# output
```

`gradient!` fills both gradient entries.

## Constrained problem

Hock-Schittkowski problem 71 has four variables and two constraints.

```text
minimize    x1*x4*(x1 + x2 + x3) + x3
subject to  x1*x2*x3*x4 >= 25
            x1^2 + x2^2 + x3^2 + x4^2 = 40
            1 <= xi <= 5
```

The known objective is approximately `17.014017`.

```jldoctest hs71
using SNOPT
using SparseArrays

objective(x) = x[1] * x[4] * (x[1] + x[2] + x[3]) + x[3]

function gradient!(gradient, x)
    gradient[1] = x[4] * (2.0 * x[1] + x[2] + x[3])
    gradient[2] = x[1] * x[4]
    gradient[3] = x[1] * x[4] + 1.0
    gradient[4] = x[1] * (x[1] + x[2] + x[3])
    return nothing
end

function constraints!(values, x)
    values[1] = x[1] * x[2] * x[3] * x[4]
    values[2] = sum(abs2, x)
    return nothing
end

function jacobian!(nonzeros, x)
    nonzeros[1] = x[2] * x[3] * x[4]
    nonzeros[2] = 2.0 * x[1]
    nonzeros[3] = x[1] * x[3] * x[4]
    nonzeros[4] = 2.0 * x[2]
    nonzeros[5] = x[1] * x[2] * x[4]
    nonzeros[6] = 2.0 * x[3]
    nonzeros[7] = x[1] * x[2] * x[3]
    nonzeros[8] = 2.0 * x[4]
    return nothing
end

J = sparse(
    [1, 2, 1, 2, 1, 2, 1, 2],
    [1, 1, 2, 2, 3, 3, 4, 4],
    ones(8),
    2,
    4,
)

result = snopt(
    objective,
    gradient!,
    [1.0, 5.0, 5.0, 1.0];
    lb = ones(4),
    ub = fill(5.0, 4),
    eval_con = constraints!,
    eval_jac = jacobian!,
    lcon = [25.0, 40.0],
    ucon = [Inf, 40.0],
    J,
    options = ["Major print level" => 0],
)

@assert result.status_symbol == :Solve_Succeeded
@assert isapprox(result.objective, 17.014017; atol = 1.0e-5)
@assert isapprox(result.x, [1.0, 4.743, 3.821, 1.379]; atol = 1.0e-3)

# output
```

The Jacobian is dense, but `J` makes the storage order explicit.
`jacobian!` fills entries by column, in `J.nzval` order.
