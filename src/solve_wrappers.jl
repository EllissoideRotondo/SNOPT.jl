function start_mode_code(start::AbstractString)::Cint
    key = lowercase(strip(start))
    key == "cold" && return Cint(0)
    key == "warm" && return Cint(1)
    key == "hot"  && return Cint(2)
    throw(ArgumentError("SNOPT start mode must be Cold, Warm, or Hot; got $(repr(start))"))
end

function snopt!(prob::SnoptB; start::String = "Cold", name::String = "Julia",
                snlog=nothing)
    return snoptb!(prob; start, name, snlog)
end

function snoptb!(prob::SnoptB; start::String = "Cold", name::String = "Julia",
                 snlog=nothing)
    nc    = prob.nc
    nnCon = nc
    nnJac = nc > 0 ? prob.n : 0
    inform = snoptb!(prob.ws, start, name,
                     prob.m_eff, prob.n, nnCon, prob.nnobj, nnJac,
                     0.0, 0,
                     prob.confun, prob.objfun,
                     prob.J, prob.bl, prob.bu, prob.hs, prob.x;
                     snlog)
    prob.obj_val = prob.ws.obj_val
    prob.status  = inform
    prob.lambda  = prob.ws.lambda
    return inform
end

function snopt!(prob::SnoptA; start::String = "Cold", name::String = "Julia")
    return snopta!(prob; start, name)
end

function snopt!(prob::SnoptC; start::String = "Cold", name::String = "Julia",
                snlog=nothing)
    return snoptc!(prob; start, name, snlog)
end
