"""
    SnoptWorkspace

SNOPT session with its integer and real work arrays.

Create a workspace with [`initialize`](@ref), and close it with `close` or with the
`do` form of [`initialize`](@ref). `isopen(workspace)` tells if it is still open.
Only one workspace can be open in a Julia process: [`initialize`](@ref) closes the
previous one. [`snopt`](@ref) manages its own workspace, so this type is needed only
for the [Low-level interface](@ref).

The only public field is `iw`, the integer work array, which the callback builders
[`make_objfun`](@ref), [`make_confun`](@ref) and [`make_usrfun_c`](@ref) take as an
argument.
"""
mutable struct SnoptWorkspace
    status::Int
    finalized::Bool
    init_id::Int       # ID of the f_sninitx call; 0 = not yet initialized via f_sninitx
    leniw::Int
    lenrw::Int
    tempfiles::Vector{String}
    iw::Vector{Int32}
    rw::Vector{Float64}
    leniu::Int
    lenru::Int
    iu::Vector{Int32}
    ru::Vector{Float64}
    x::Vector{Float64}
    lambda::Vector{Float64}
    obj_val::Float64
    num_inf::Int
    sum_inf::Float64
    iterations::Int
    major_itns::Int
    run_time::Float64
    nS::Int
    function SnoptWorkspace(leniw::Int, lenrw::Int)
        # SNOPT's sninit writes a fixed-size header into iw/rw and requires at
        # least 500 elements in each. Smaller arrays let f_sninitx write out of
        # bounds, which silently corrupts the heap and later segfaults, so reject
        # them before any allocation reaches the Fortran side.
        leniw >= 500 || throw(ArgumentError("leniw must be >= 500 (SNOPT work-array minimum), got $leniw"))
        lenrw >= 500 || throw(ArgumentError("lenrw must be >= 500 (SNOPT work-array minimum), got $lenrw"))
        prob = new(0, false, 0, leniw, lenrw, String[],
                   zeros(Int32, leniw), zeros(Float64, lenrw),
                   0, 0,
                   Int32[0], [0.0],
                   Float64[], Float64[], 0.0,
                   0, 0.0, 0, 0, 0.0, 0)
        finalizer(gc_finalize_workspace!, prob)
        prob
    end
end

"""
    AbstractSnoptProblem

Supertype of the low-level problem types [`SnoptA`](@ref), [`SnoptB`](@ref) and
[`SnoptC`](@ref).

Each problem holds a [`SNOPT.SnoptWorkspace`](@ref), the problem data and the user
functions. [`snopt!`](@ref) solves any subtype in place.
"""
abstract type AbstractSnoptProblem end

"""
    SnoptA(ws, nf, n, objadd, objrow, iAfun, jAvar, A, iGfun, jGvar,
           xlow, xupp, flow, fupp, x, xstate, xmul, F, Fstate, Fmul,
           status, nS, num_inf, sum_inf, usrfun)

Low-level problem for SNOPT's `snOptA` interface; solve it with [`snopta!`](@ref). The
positional arguments are the fields below. See [Low-level interface](@ref).

The objective and the constraints form one vector `F(x)` of `nf` rows, with the
objective in row `objrow`. The derivatives of `F` are split into constant entries and
entries that `usrfun` computes.

# Fields

  - `ws`: open [`SNOPT.SnoptWorkspace`](@ref).
  - `nf`, `n`: number of rows of `F` and number of variables.
  - `objadd`, `objrow`: constant added to the objective, and its row (`0` for none).
  - `iAfun`, `jAvar`, `A`: rows, columns (`Int32`) and values of the constant entries.
  - `iGfun`, `jGvar`: rows and columns (`Int32`) of the entries that `usrfun` computes.
  - `xlow`, `xupp`, `flow`, `fupp`: bounds of `x` (length `n`) and of `F` (length
    `nf`); `±1.0e20` means no bound.
  - `x`, `xstate`, `xmul`: variables, basis states (`Int32`) and multipliers, length
    `n`. `x` holds the starting point, then the solution.
  - `F`, `Fstate`, `Fmul`: the same for the rows, length `nf`.
  - `status`, `nS`, `num_inf`, `sum_inf`: outputs; pass `0, 0, 0, 0.0`.
  - `usrfun`: function from [`make_usrfun_a`](@ref).
"""
mutable struct SnoptA{F} <: AbstractSnoptProblem
    ws::SnoptWorkspace
    nf::Int                           # number of F rows: objective + constraints
    n::Int                            # number of design variables
    objadd::Float64                   # objective constant term
    objrow::Int                       # objective row, 0 means no objective row
    iAfun::Vector{Int32}              # linear Jacobian row indices
    jAvar::Vector{Int32}              # linear Jacobian variable indices
    A::Vector{Float64}                # linear Jacobian values
    iGfun::Vector{Int32}              # nonlinear Jacobian row indices
    jGvar::Vector{Int32}              # nonlinear Jacobian variable indices
    xlow::Vector{Float64}
    xupp::Vector{Float64}
    flow::Vector{Float64}
    fupp::Vector{Float64}
    x::Vector{Float64}
    xstate::Vector{Int32}
    xmul::Vector{Float64}
    F::Vector{Float64}
    Fstate::Vector{Int32}
    Fmul::Vector{Float64}
    status::Int
    nS::Int
    num_inf::Int
    sum_inf::Float64
    usrfun::F
end

"""
    SnoptB(ws, n, nc, m_eff, nnobj, x, bl, bu, hs, J, obj_val, status, lambda,
           objfun, confun, nS = 0)

Low-level problem for SNOPT's `snOptB` interface, with separate objective and
constraint functions; solve it with [`snoptb!`](@ref). The positional arguments are the
fields below. See [Low-level interface](@ref).

# Fields

  - `ws`: open [`SNOPT.SnoptWorkspace`](@ref).
  - `n`, `nc`: number of variables and of constraints; all constraints are nonlinear.
  - `m_eff`: number of rows, `max(nc, 1)`; SNOPT needs at least one.
  - `nnobj`: the objective is nonlinear in `x[1:nnobj]`; usually `n`.
  - `x`, `bl`, `bu`, `hs`: values, bounds and basis states (`Int32`) of the variables
    followed by one slack variable per row, length `n + m_eff`. `±1.0e20` means no
    bound; `hs` is zero for a cold start.
  - `J`: `m_eff × n` sparsity pattern, a `SparseMatrixCSC{Float64, Int32}` with at
    least one entry.
  - `obj_val`, `status`, `lambda`: outputs; pass `0.0, 0, Float64[]`.
  - `objfun`, `confun`: from [`make_objfun`](@ref), and from [`make_confun`](@ref) or
    [`make_dummy_confun`](@ref).
  - `nS`: number of superbasic variables; `0` for a cold start.
"""
mutable struct SnoptB{F1, F2} <: AbstractSnoptProblem
    ws::SnoptWorkspace
    n::Int                            # num design variables
    nc::Int                           # num nonlinear constraints
    m_eff::Int                        # effective m passed to Fortran (>= 1; nc when nc>0, else 1)
    nnobj::Int                        # num nonlinear objective variables (<= n)
    x::Vector{Float64}                # [n+m_eff] extended point (initial / final)
    bl::Vector{Float64}               # [n+m_eff] lower bounds
    bu::Vector{Float64}               # [n+m_eff] upper bounds
    hs::Vector{Int32}                 # [n+m_eff] basis status
    J::SparseMatrixCSC{Float64,Int32} # m_eff×n Jacobian (sparsity structure)
    obj_val::Float64                  # filled after solve
    status::Int                       # SNOPT inform code, filled after solve
    lambda::Vector{Float64}           # multipliers, filled after solve
    objfun::F1
    confun::F2
    nS::Int                           # superbasics count, retained for warm starts
end

# Keeps the pre-0.3 positional form working; nS defaults to 0 (cold start).
SnoptB(ws, n, nc, m_eff, nnobj, x, bl, bu, hs, J, obj_val, status, lambda,
       objfun, confun) =
    SnoptB(ws, n, nc, m_eff, nnobj, x, bl, bu, hs, J, obj_val, status, lambda,
           objfun, confun, 0)

"""
    SnoptProblem

Alias for [`SnoptB`](@ref).
"""
const SnoptProblem = SnoptB

"""
    SnoptC(ws, n, nc, m_eff, nnobj, x, bl, bu, hs, J, obj_val, status, lambda,
           usrfun, nS = 0)

Low-level problem for SNOPT's `snOptC` interface, with one function for the objective
and the constraints. Solve it with [`snoptc!`](@ref).

The fields are the same as those of [`SnoptB`](@ref), except that one function
`usrfun` replaces `objfun` and `confun`. Build `usrfun` with
[`make_usrfun_c`](@ref). See [Low-level interface](@ref) for an example.
"""
mutable struct SnoptC{F} <: AbstractSnoptProblem
    ws::SnoptWorkspace
    n::Int                            # num design variables
    nc::Int                           # num nonlinear constraints
    m_eff::Int                        # effective m passed to Fortran
    nnobj::Int                        # num nonlinear objective variables (<= n)
    x::Vector{Float64}                # [n+m_eff] extended point (initial / final)
    bl::Vector{Float64}               # [n+m_eff] lower bounds
    bu::Vector{Float64}               # [n+m_eff] upper bounds
    hs::Vector{Int32}                 # [n+m_eff] basis status
    J::SparseMatrixCSC{Float64,Int32} # m_eff×n Jacobian (sparsity structure)
    obj_val::Float64                  # filled after solve
    status::Int                       # SNOPT inform code, filled after solve
    lambda::Vector{Float64}           # multipliers, filled after solve
    usrfun::F
    nS::Int                           # superbasics count, retained for warm starts
end

# Keeps the pre-0.3 positional form working; nS defaults to 0 (cold start).
SnoptC(ws, n, nc, m_eff, nnobj, x, bl, bu, hs, J, obj_val, status, lambda,
       usrfun) =
    SnoptC(ws, n, nc, m_eff, nnobj, x, bl, bu, hs, J, obj_val, status, lambda,
           usrfun, 0)

"""
    SnoptMemory

Minimum workspace sizes returned by [`snmemb`](@ref).

# Fields

  - `info`: SNOPT status code of the estimate. `100` and `104` mean success.
  - `miniw`: minimum length of the integer work array.
  - `minrw`: minimum length of the real work array.
"""
struct SnoptMemory
    info::Int
    miniw::Int
    minrw::Int
end

"""
    SnoptBasis

Basis at the end of a solve, for a warm start with [`snopt`](@ref).

Pass `result.basis` as the `basis` keyword of a later call, together with
`start = "Warm"`. See [Warm and hot starts](@ref) and [Solver concepts](@ref).

# Fields

  - `hs`: basis state of each variable and slack variable (`Int32`), length `n + m`.
  - `nS`: number of superbasic variables.
  - `n`: number of variables.
  - `m`: number of constraint rows; `1` for a problem without constraints.
"""
struct SnoptBasis
    hs::Vector{Int32}
    nS::Int
    n::Int
    m::Int
end

"""
    SnoptStatus

Status of a SNOPT solve. Each value of type `SnoptStatus.T` is a SNOPT 7.7 status code:
`SnoptStatus.T(51)` gives `SnoptStatus.IncorrectObjectiveDerivatives`, and `Int` gives
the code back. The tens digit is the group, so `Int(status) ÷ 10 == 1` holds for every
infeasible outcome. `SnoptStatus.Unknown` (`0`) stands for a code that the SNOPT 7.7 user
guide does not list. [Solver concepts](@ref) describes each group.

# Examples

```jldoctest
julia> SnoptStatus.T(51)
SnoptStatus.IncorrectObjectiveDerivatives = 51

julia> Int(SnoptStatus.TimeLimit)
34
```
"""
module SnoptStatus
@enum T::Int begin
    Unknown                           = 0
    # Finished successfully
    Optimal                           = 1
    FeasiblePoint                     = 2
    AccuracyNotAchieved               = 3
    ElasticObjectiveMinimized         = 5
    ElasticInfeasibilitiesMinimized   = 6
    # The problem appears to be infeasible
    InfeasibleLinear                  = 11
    InfeasibleLinearEqualities        = 12
    NonlinearInfeasibilitiesMinimized = 13
    LinearInfeasibilitiesMinimized    = 14
    InfeasibleQPSubproblem            = 15
    InfeasibleNonelastic              = 16
    # The problem appears to be unbounded
    UnboundedObjective                = 21
    ConstraintViolationLimit          = 22
    # Resource limit error
    IterationLimit                    = 31
    MajorIterationLimit               = 32
    SuperbasicsLimit                  = 33
    TimeLimit                         = 34
    # Terminated after numerical difficulties
    CannotImprove                     = 41
    SingularBasis                     = 42
    CannotSatisfyConstraints          = 43
    IllConditionedNullSpace           = 44
    LUFactorizationFailed             = 45
    # Error in the user-supplied functions
    IncorrectObjectiveDerivatives     = 51
    IncorrectConstraintDerivatives    = 52
    BadlyScaledFunctions              = 56
    # Undefined user-supplied functions
    UndefinedAtFirstFeasiblePoint     = 61
    UndefinedAtInitialPoint           = 62
    UndefinedRegion                   = 63
    # User requested termination
    StopInFunction                    = 71
    StopInConstraints                 = 72
    StopInObjective                   = 73
    StopInMonitor                     = 74
    # Insufficient storage allocated
    WorkArraysTooSmall                = 81
    CharacterStorage                  = 82
    IntegerStorage                    = 83
    RealStorage                       = 84
    # Input arguments out of range
    InvalidInput                      = 91
    BasisFileMismatch                 = 92
    # System error
    WrongBasicVariableCount           = 141
    BasisPackageError                 = 142
end

Base.show(io::IO, status::T) = print(io, "SnoptStatus.", Symbol(status))
function Base.show(io::IO, ::MIME"text/plain", status::T)
    show(io, status)
    print(io, " = ", Int(status))
end
end

"""
    SNOPT.status_from_code(code::Integer) -> SnoptStatus.T

Return the [`SnoptStatus`](@ref) value of the SNOPT status code `code`, or
`SnoptStatus.Unknown` for a code that the SNOPT 7.7 user guide does not list. Unlike
`SnoptStatus.T(code)`, it never throws, so it is safe to call on the code returned by
[`snopt!`](@ref), [`snopta!`](@ref), [`snoptb!`](@ref) or [`snoptc!`](@ref).
"""
function status_from_code(code::Integer)
    code in Int.(instances(SnoptStatus.T)) || return SnoptStatus.Unknown
    return SnoptStatus.T(code)
end

"""
    SnoptResult

Result of [`snopt`](@ref).

Check `status` before using `x`, for example `result.status == SnoptStatus.Optimal`.

# Fields

  - `status`: outcome of the solve, a [`SnoptStatus`](@ref) value; `Int(status)` is the
    SNOPT status code.
  - `objective`: objective value at `x`.
  - `x`: solution, length `n`.
  - `lambda`: Lagrange multipliers, one per variable and then one per constraint.
  - `num_inf`: number of bounds and constraints that are still violated.
  - `sum_inf`: sum of these violations.
  - `iterations`: total number of minor iterations.
  - `major_itns`: number of major iterations.
  - `run_time`: CPU time of the solve reported by SNOPT, in seconds.
  - `memory`: [`SnoptMemory`](@ref) used to size the workspace.
  - `basis`: [`SnoptBasis`](@ref) for a warm start.

If a `callback` function stopped the solve before SNOPT started, `basis` contains no
information and the iteration counts are zero.
"""
struct SnoptResult
    status::SnoptStatus.T
    objective::Float64
    x::Vector{Float64}
    lambda::Vector{Float64}
    num_inf::Int
    sum_inf::Float64
    iterations::Int
    major_itns::Int
    run_time::Float64
    memory::SnoptMemory
    basis::SnoptBasis
end

"""
    SnoptMajorLog

State of the solve at the end of a major iteration, passed to `snlog`. Return `false`
to stop the solve. The arrays are copies; most values refer to SNOPT's scaled problem.
See [Monitor and stop a solve](@ref).

# Fields

  - `iteration`, `major_iter`, `minor_iter`: total minor iterations, current major
    iteration, and minor iterations in it.
  - `n_superbasics`, `n_swaps`: number of superbasic variables and of basis changes.
  - `objective`: objective value, including `objective_add` and a linear objective row.
  - `merit`: merit function, the objective plus a penalty on the constraint violation.
  - `f_objective`, `f_merit`: nonlinear parts of the objective and of the merit function.
  - `primal_infeasibility`, `dual_infeasibility`: constraint violation and error in the
    optimality conditions.
  - `max_violation`, `relative_violation`: largest constraint violation, absolute and
    relative.
  - `step`, `penalty_norm`: length of the last step and norm of the penalty parameters.
  - `condition_hessian`: estimated condition number of the reduced Hessian.
  - `objective_scale`, `objective_add`: scale factor and constant of the objective.
  - `minimize`: `1` to minimize, `-1` to maximize.
  - `kt_conditions`: two flags, `true` when the primal and the dual
    Karush–Kuhn–Tucker conditions hold.
  - `n`, `nb`, `nncon`, `nnobj`: number of variables, of variables plus slack
    variables, of nonlinear constraints and of nonlinear objective variables.
  - `x`, `hs`: variables followed by slack variables, and their basis states; length
    `nb`.
  - `fcon`, `fx`, `ycon`: nonlinear constraint values as SNOPT passes them (`fCon` and
    `Fx`), and their multipliers; length `nncon`.
"""
struct SnoptMajorLog
    iteration::Int
    major_iter::Int
    minor_iter::Int
    n_superbasics::Int
    n_swaps::Int
    objective::Float64
    merit::Float64
    penalty_norm::Float64
    step::Float64
    primal_infeasibility::Float64
    dual_infeasibility::Float64
    max_violation::Float64
    relative_violation::Float64
    condition_hessian::Float64
    objective_scale::Float64
    objective_add::Float64
    f_objective::Float64
    f_merit::Float64
    minimize::Int
    n::Int
    nb::Int
    nncon::Int
    nnobj::Int
    kt_conditions::NTuple{2, Bool}
    x::Vector{Float64}
    fcon::Vector{Float64}
    fx::Vector{Float64}
    ycon::Vector{Float64}
    hs::Vector{Int32}
end

"""
    SnoptStopEvent

State of the solve at the end of one major iteration, passed to the `snstop` function.

This type has all the fields of [`SnoptMajorLog`](@ref) and the fields below. Return
`false` from `snstop` to stop the solve; the result then has the status
`SnoptStatus.StopInMonitor`. See [Monitor and stop a solve](@ref).

# Fields

  - `m`: number of constraint rows.
  - `max_superbasics`: largest allowed number of superbasic variables.
  - `negcon`: number of nonlinear Jacobian entries.
  - `gobj`: objective gradient, length `nnobj`.
  - `gcon`: nonlinear Jacobian entries, length `negcon`.
  - `pi`: multipliers of the rows, length `m`.
  - `rc`: reduced costs of the variables and slack variables, length `nb`.
  - `rg`: reduced gradient, length `max_superbasics`.
  - `bl`, `bu`: scaled lower and upper bounds, length `nb`.
"""
struct SnoptStopEvent
    iteration::Int
    major_iter::Int
    minor_iter::Int
    n_superbasics::Int
    max_superbasics::Int
    n_swaps::Int
    objective::Float64
    merit::Float64
    penalty_norm::Float64
    step::Float64
    primal_infeasibility::Float64
    dual_infeasibility::Float64
    max_violation::Float64
    relative_violation::Float64
    condition_hessian::Float64
    objective_scale::Float64
    objective_add::Float64
    f_objective::Float64
    f_merit::Float64
    minimize::Int
    m::Int
    n::Int
    nb::Int
    nncon::Int
    nnobj::Int
    negcon::Int
    kt_conditions::NTuple{2, Bool}
    x::Vector{Float64}
    bl::Vector{Float64}
    bu::Vector{Float64}
    fcon::Vector{Float64}
    fx::Vector{Float64}
    gcon::Vector{Float64}
    gobj::Vector{Float64}
    ycon::Vector{Float64}
    pi::Vector{Float64}
    rc::Vector{Float64}
    rg::Vector{Float64}
    hs::Vector{Int32}
end
