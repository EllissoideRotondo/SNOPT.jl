# Minimize (x - 1)^2 + (y - 2)^2.
#
# Run from the SNOPT.jl repository root:
#   julia --project=. examples/unconstrained.jl
using SNOPT

function objective(x)
    return (x[1] - 1)^2 + (x[2] - 2)^2
end

function gradient!(g, x)
    g[1] = 2(x[1] - 1)
    g[2] = 2(x[2] - 2)
    return nothing
end

function progress(event::SnoptMajorLog)
    println("major $(event.major_iter): objective = $(event.objective)")
    return true
end

result = snopt(
    objective,
    gradient!,
    [0.0, 0.0];
    lb = -10.0,
    ub = 10.0,
    options = [
        "Major print level" => 1,
        "Minor print level" => 0,
    ],
    snlog = progress,
    printfile = joinpath(@__DIR__, "unconstrained.out"),
)

@assert result.status_symbol == :Solve_Succeeded
@assert isapprox(result.objective, 0.0; atol = 1.0e-8)
@assert isapprox(result.x, [1.0, 2.0]; atol = 1.0e-6)
