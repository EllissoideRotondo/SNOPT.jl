# snopt-interface's f_snoptb/f_snoptc/f_snkerb/f_snkerc map their integer start
# argument as 1 => 'Warm', 2 => 'Hot', anything else => 'Cold'.
function validate_problem_name(name::String)
    ncodeunits(name) <= 8 ||
        throw(ArgumentError("SNOPT problem name must contain at most 8 bytes; got $(ncodeunits(name))"))
    occursin('\0', name) &&
        throw(ArgumentError("SNOPT problem name must not contain a null byte"))
    return name
end

function start_mode_code(start::AbstractString)::Cint
    key = lowercase(strip(start))
    key == "cold" && return Cint(0)
    key == "warm" && return Cint(1)
    key == "hot"  && return Cint(2)
    throw(ArgumentError("SNOPT start mode must be Cold, Warm, or Hot; got $(repr(start))"))
end

# f_snopta forwards its integer start argument unchanged to snOptA, which uses
# 0 = Cold, 1 = Basis file, 2 = Warm, 3 = Hot — a different convention from the
# snOptB/snOptC wrappers above.
function start_mode_code_a(start::AbstractString)::Cint
    key = lowercase(strip(start))
    key == "cold" && return Cint(0)
    key == "warm" && return Cint(2)
    key == "hot"  && return Cint(3)
    throw(ArgumentError("SNOPT start mode must be Cold, Warm, or Hot; got $(repr(start))"))
end

"""
    snopt!(prob::AbstractSnoptProblem; start = "Cold", name = "Julia",
           snlog = nothing, snstop = nothing) -> Int

Solve the low-level problem `prob` in place with [`snopta!`](@ref), [`snoptb!`](@ref)
or [`snoptc!`](@ref), and return the SNOPT status code.

`start` is `"Cold"`, `"Warm"` (from the basis in `prob`) or `"Hot"` (also reuses the
factorization and Hessian of the previous solve of `prob` in the same workspace).
`snlog`, `snstop` and `name` work as in [`snopt`](@ref).

Throws an `ArgumentError` if the workspace is closed, a solve is running, or `start` or
`name` is not valid. An error in a user function is thrown again after the solve.
"""
function snopt!(prob::SnoptB; start::String = "Cold", name::String = "Julia",
                snlog=nothing, snstop=nothing)
    return snoptb!(prob; start, name, snlog, snstop)
end

"""
    snoptb!(prob::SnoptB; start = "Cold", name = "Julia", snlog = nothing,
            snstop = nothing) -> Int

Solve `prob` in place with SNOPT's `snOptB` interface and return the SNOPT status code.

After the solve, `prob.x`, `prob.obj_val`, `prob.lambda`, `prob.hs`, `prob.nS` and
`prob.status` hold the result. The keywords are the same as for [`snopt!`](@ref).
"""
function snoptb!(prob::SnoptB; start::String = "Cold", name::String = "Julia",
                 snlog=nothing, snstop=nothing)
    return lock(SNOPT_LOCK) do
        snoptb_problem_locked!(prob, start, name, snlog, snstop)
    end
end

function snoptb_problem_locked!(prob::SnoptB, start::String, name::String, snlog, snstop)
    require_open_workspace(prob.ws, "snoptb!")
    nc    = prob.nc
    nnCon = nc
    nnJac = nc > 0 ? prob.n : 0
    inform = snoptb!(prob.ws, start, name,
                     prob.m_eff, prob.n, nnCon, prob.nnobj, nnJac,
                     0.0, 0,
                     prob.confun, prob.objfun,
                     prob.J, prob.bl, prob.bu, prob.hs, prob.x;
                     snlog, snstop, nS = prob.nS)
    prob.obj_val = prob.ws.obj_val
    prob.status  = inform
    prob.nS      = prob.ws.nS
    prob.lambda  = prob.ws.lambda
    return inform
end

function snopt!(prob::SnoptA; start::String = "Cold", name::String = "Julia",
                snlog=nothing, snstop=nothing)
    return snopta!(prob; start, name, snlog, snstop)
end

function snopt!(prob::SnoptC; start::String = "Cold", name::String = "Julia",
                snlog=nothing, snstop=nothing)
    return snoptc!(prob; start, name, snlog, snstop)
end
