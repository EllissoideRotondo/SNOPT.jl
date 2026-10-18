function option_keyword(key::AbstractString)
    keyword = String(strip(String(key)))
    isempty(keyword) &&
        throw(ArgumentError("SNOPT option keyword must not be empty or whitespace-only"))
    return keyword
end

function option_keyword(key::Symbol)
    return option_keyword(replace(String(key), "_" => " "))
end

function option_keyword(key)
    throw(ArgumentError("SNOPT option keyword must be a String or Symbol, got $(typeof(key))"))
end

function apply_option!(ws::SnoptWorkspace, option::Pair)
    key = option_keyword(first(option))
    value = last(option)
    if value isa Bool
        throw(ArgumentError("SNOPT option $(repr(key)) does not accept Bool values"))
    elseif value isa Integer
        set_option!(ws, key, Int(value))
    elseif value isa AbstractFloat
        float_value = Float64(value)
        isfinite(float_value) ||
            throw(ArgumentError("SNOPT option $(repr(key)) requires a finite floating-point value"))
        set_option!(ws, key, float_value)
    elseif value isa AbstractString
        string_value = String(strip(String(value)))
        isempty(string_value) &&
            throw(ArgumentError("SNOPT option $(repr(key)) string value must not be empty or whitespace-only"))
        set_option!(ws, string(key, " ", string_value))
    elseif value isa Symbol
        set_option!(ws, string(key, " ", option_keyword(value)))
    else
        throw(ArgumentError("SNOPT option $(repr(key)) value must be an integer, finite float, string, or symbol; got $(typeof(value))"))
    end
    return ws
end

function apply_options!(ws::SnoptWorkspace, options::Nothing)
    return lock(SNOPT_LOCK) do
        require_open_workspace(ws, "apply_options!")
        return ws
    end
end

function apply_options!(ws::SnoptWorkspace, options::AbstractVector{<:Pair})
    return lock(SNOPT_LOCK) do
        require_open_workspace(ws, "apply_options!")
        for option in options
            apply_option!(ws, option)
        end
        return ws
    end
end

function apply_options!(ws::SnoptWorkspace, options)
    throw(ArgumentError("SNOPT options must be a Vector of Pairs, got $(typeof(options))"))
end

"""
    set_option!(ws, option::String) -> Int
    set_option!(ws, name::String, value::Real) -> Int

Set one SNOPT option in the workspace `ws` and return `0`.

`ws` is an open [`SNOPT.SnoptWorkspace`](@ref) or a low-level problem. The first
form takes the full option text, for example `"Hessian limited memory"`. The second
form takes the option name and a number, for example
`set_option!(ws, "Major iterations limit", 500)`.

Throws an `ArgumentError` if SNOPT does not accept the option, if `value` is a `Bool`
or not finite, or if the workspace is closed. To set options in [`snopt`](@ref), use
its `options` keyword instead; see [Set solver options](@ref).
"""
set_option!(prob::Union{SnoptA, SnoptB, SnoptC}, args...) = set_option!(prob.ws, args...)

function check_option_errors(errors, label)
    errors == 0 && return Int(errors)
    throw(ArgumentError("SNOPT rejected option $(label) with $(Int(errors)) error(s)"))
end

function set_option!(prob::SnoptWorkspace, optstring::String)
    return lock(SNOPT_LOCK) do
        require_open_workspace(prob, "set_option!")
        isempty(strip(optstring)) &&
            throw(ArgumentError("SNOPT option string must not be empty or whitespace-only"))
        errors = Int32[0]
        ccall((:f_snset, libsnopt7), Cvoid,
              (Cstring, Cint, Ptr{Cint},
               Ptr{Cint}, Cint, Ptr{Cdouble}, Cint),
              optstring, Cint(ncodeunits(optstring)), errors,
              prob.iw, prob.leniw, prob.rw, prob.lenrw)
        return check_option_errors(errors[1], repr(optstring))
    end
end

function set_option!(prob::SnoptWorkspace, keyword::String, value::Int)
    return lock(SNOPT_LOCK) do
        require_open_workspace(prob, "set_option!")
        isempty(strip(keyword)) &&
            throw(ArgumentError("SNOPT option keyword must not be empty or whitespace-only"))
        errors = Int32[0]
        ccall((:f_snseti, libsnopt7), Cvoid,
              (Cstring, Cint, Cint, Ptr{Cint},
               Ptr{Cint}, Cint, Ptr{Cdouble}, Cint),
              keyword, Cint(ncodeunits(keyword)), value, errors,
              prob.iw, prob.leniw, prob.rw, prob.lenrw)
        return check_option_errors(errors[1], "$(repr(keyword)) => $(value)")
    end
end

# Convert supported numeric types to the native integer and real methods.
set_option!(prob::SnoptWorkspace, keyword::String, value::Bool) =
    throw(ArgumentError("SNOPT option $(repr(keyword)) does not accept Bool values"))
set_option!(prob::SnoptWorkspace, keyword::String, value::Integer) =
    set_option!(prob, keyword, Int(value))
set_option!(prob::SnoptWorkspace, keyword::String, value::Real) =
    set_option!(prob, keyword, Float64(value))

function set_option!(prob::SnoptWorkspace, keyword::String, value::Float64)
    return lock(SNOPT_LOCK) do
        require_open_workspace(prob, "set_option!")
        isempty(strip(keyword)) &&
            throw(ArgumentError("SNOPT option keyword must not be empty or whitespace-only"))
        isfinite(value) ||
            throw(ArgumentError("SNOPT option $(repr(keyword)) requires a finite value, got $value"))
        errors = Int32[0]
        ccall((:f_snsetr, libsnopt7), Cvoid,
              (Cstring, Cint, Cdouble, Ptr{Cint},
               Ptr{Cint}, Cint, Ptr{Cdouble}, Cint),
              keyword, Cint(ncodeunits(keyword)), value, errors,
              prob.iw, prob.leniw, prob.rw, prob.lenrw)
        return check_option_errors(errors[1], "$(repr(keyword)) => $(value)")
    end
end
