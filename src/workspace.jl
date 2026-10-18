# The latest initialized workspace owns SNOPT's process-wide Fortran state.
# Atomic compare-and-swap prevents finalizers from ending a superseded session.
const _SNOPT_ACTIVE_ID = Threads.Atomic{Int}(0)
const _SNOPT_ID_COUNTER = Threads.Atomic{Int}(0)
const _SNOPT_ACTIVE_WORKSPACE = Ref{Any}(nothing)

# Serialize workspace creation, native calls, and explicit cleanup.
# Reentrancy permits high-level operations to call lower-level entry points.
# The solve flag separately rejects callback reentry into the Fortran session.
const SNOPT_LOCK = ReentrantLock()
const _SNOPT_SOLVE_ACTIVE = Ref(false)

function require_idle_snopt(action::AbstractString)
    _SNOPT_SOLVE_ACTIVE[] && throw(ArgumentError(
        "$(action) cannot run during an active SNOPT solve; call it after the solve returns"))
    return nothing
end

function reset_snopt_defaults!(prob::SnoptWorkspace)
    optstring = "Defaults"
    errors = Int32[0]
    ccall((:f_snset, libsnopt7), Cvoid,
          (Cstring, Cint, Ptr{Cint},
           Ptr{Cint}, Cint, Ptr{Cdouble}, Cint),
          optstring, Cint(ncodeunits(optstring)), errors,
          prob.iw, prob.leniw, prob.rw, prob.lenrw)
    errors[1] == 0 ||
        error("SNOPT rejected Defaults option during workspace initialization")
    return prob
end

function free!(prob::SnoptWorkspace)
    return lock(SNOPT_LOCK) do
        prob.finalized && return nothing
        require_idle_snopt("close")
        close_workspace_locked!(prob)
    end
end

# Only explicit close may end the process-wide Fortran session.
function close_workspace_locked!(prob::SnoptWorkspace)
    prob.finalized && return nothing
    prob.finalized = true
    if !isempty(libsnopt7)
        # Uninitialized and superseded workspaces must never call f_snend.
        id = prob.init_id
        should_end = id != 0 && Threads.atomic_cas!(_SNOPT_ACTIVE_ID, id, 0) == id
        if should_end
            try
                ccall((:f_snend, libsnopt7),
                      Cvoid, (Ptr{Cint}, Cint, Ptr{Float64}, Cint),
                      prob.iw, prob.leniw, prob.rw, prob.lenrw)
            catch
                # The shared library may already be unavailable during shutdown.
            end
        end
    end
    cleanup_workspace_files!(prob)
    _SNOPT_ACTIVE_WORKSPACE[] === prob && (_SNOPT_ACTIVE_WORKSPACE[] = nothing)
    return nothing
end

function cleanup_workspace_files!(prob::SnoptWorkspace)
    for path in prob.tempfiles
        try
            isfile(path) && rm(path; force=true)
        catch
            # Temporary output cleanup should never make finalization fail.
        end
    end
    empty!(prob.tempfiles)
    return nothing
end

# GC finalizers never call SNOPT. Active sessions remain strongly rooted and
# are closed explicitly or when the next workspace is initialized.
function gc_finalize_workspace!(prob::SnoptWorkspace)
    prob.finalized && return nothing
    _SNOPT_ACTIVE_WORKSPACE[] === prob && return nothing
    prob.finalized = true
    cleanup_workspace_files!(prob)
    return nothing
end

function close_active_workspace!()
    active = _SNOPT_ACTIVE_WORKSPACE[]
    if active isa SnoptWorkspace && !active.finalized
        free!(active)
    else
        _SNOPT_ACTIVE_WORKSPACE[] = nothing
    end
    return nothing
end

Base.close(prob::SnoptWorkspace) = free!(prob)
Base.isopen(prob::SnoptWorkspace) = !prob.finalized

function require_open_workspace(prob::SnoptWorkspace, action::AbstractString)
    require_idle_snopt(action)
    isopen(prob) ||
        throw(ArgumentError("$(action) requires an open SNOPT workspace"))
    return prob
end

const IW_MINOR_ITNS = 421  # iw(421): cumulative minor iterations - SNOPT 7.7 iw layout

const IW_MAJOR_ITNS = 422  # iw(422): cumulative major iterations - SNOPT 7.7 iw layout

const RW_RUN_TIME   = 462  # rw(462): CPU run time in seconds    - SNOPT 7.7 rw layout

workspace_value(ws_rw::Vector{Float64}, index::Int) =
    length(ws_rw) >= index ? max(ws_rw[index], 0.0) : 0.0

# On Windows the MinGW wrapper expects genuinely empty filenames for suppressed
# output channels; replacing them with "NUL" leaves the workspace partially
# initialized and the first solve can fail with bogus storage errors.
const SNOPT_DEVNULL = Sys.iswindows() ? "" : "/dev/null"

snopt_output_file(path::String) = isempty(path) ? SNOPT_DEVNULL : path

# Linux SNOPT needs one real output file to avoid status 82 in later solves.
# Create it before f_sninitx so unwritable paths raise a Julia exception.
function scratch_summary_file()
    attempts = String[]
    for dir in (nothing, homedir(), pwd())
        try
            path, io = dir === nothing ? mktemp() : mktemp(dir)
            close(io)
            return path
        catch err
            push!(attempts, something(dir, get(ENV, "TMPDIR", tempdir())))
        end
    end
    error("SNOPT.jl could not create a scratch summary file in any of: " *
          join(repr.(attempts), ", ") * ". SNOPT needs one writable output " *
          "file; pass an explicit `summfile` to choose the location yourself.")
end

function snopt_output_files(printfile::String, summfile::String)
    printpath = snopt_output_file(printfile)
    summpath = snopt_output_file(summfile)
    tempfiles = String[]
    if isempty(printfile) && isempty(summfile)
        # Keep a real summary file while suppressing visible output.
        summpath = scratch_summary_file()
        push!(tempfiles, summpath)
    end
    return printpath, summpath, tempfiles
end

"""
    initialize(printfile, summfile, leniw = 30500, lenrw = 60000) -> SnoptWorkspace
    initialize(f, printfile, summfile, leniw = 30500, lenrw = 60000)

Open a SNOPT workspace with integer and real work arrays of length `leniw` and `lenrw`
(at least 500), and return it. `printfile` and `summfile` are the paths of the SNOPT
log and summary; `""` writes no file. [`snmemb`](@ref) gives the sizes for a large
problem.

The second form calls `f(workspace)`, closes the workspace, also on error, and returns
the value of `f`. Close a workspace from the first form with `close`.

Only one workspace is open per Julia process, so `initialize` closes the previous one;
do not call it from a callback. Throws an error if the SNOPT library is not loaded.

# Examples

```julia
initialize("", "") do workspace
    set_option!(workspace, "Major print level", 0)
    # Build and solve a low-level problem.
end
```
"""
function initialize(printfile::String, summfile::String)
    initialize(printfile, summfile, 30500, 60000)
end

function initialize(printfile::String, summfile::String, leniw::Int, lenrw::Int)
    has_snopt() || error(
        "SNOPT library not loaded. Set SNOPTDIR (or DYLD_LIBRARY_PATH on macOS) " *
        "to the directory containing libsnopt7 and restart Julia, " *
        "or call SNOPT.find_snopt_lib() to diagnose.")
    return lock(SNOPT_LOCK) do
        initialize_locked(printfile, summfile, leniw, lenrw)
    end
end

function initialize_locked(printfile::String, summfile::String,
                           leniw::Int, lenrw::Int)
    require_idle_snopt("initialize")
    close_active_workspace!()
    prob = SnoptWorkspace(leniw, lenrw)
    printpath, summpath, tempfiles = snopt_output_files(printfile, summfile)
    append!(prob.tempfiles, tempfiles)
    new_id = Threads.atomic_add!(_SNOPT_ID_COUNTER, 1) + 1
    prob.init_id = new_id
    Threads.atomic_xchg!(_SNOPT_ACTIVE_ID, new_id)
    ccall((:f_sninitx, libsnopt7), Cvoid,
          (Cstring, Cint, Cstring, Cint,
           Ptr{Cint}, Cint, Ptr{Cdouble}, Cint),
          printpath, Cint(ncodeunits(printpath)), summpath, Cint(ncodeunits(summpath)),
          prob.iw, prob.leniw, prob.rw, prob.lenrw)
    try
        reset_snopt_defaults!(prob)
    catch
        # Release the session when initialization fails.
        free!(prob)
        rethrow()
    end
    _SNOPT_ACTIVE_WORKSPACE[] = prob
    return prob
end

function initialize(f::Function, printfile::String, summfile::String)
    ws = initialize(printfile, summfile)
    try
        return f(ws)
    finally
        close(ws)
    end
end

function initialize(f::Function, printfile::String, summfile::String,
                    leniw::Int, lenrw::Int)
    ws = initialize(printfile, summfile, leniw, lenrw)
    try
        return f(ws)
    finally
        close(ws)
    end
end
