using SNOPT
using Test

if !SNOPT.has_snopt()
    @info "SNOPT.jl: SNOPT library not found, skipping all tests."
    exit(0)
end

@info "Running tests with $(SNOPT.libsnopt7)"

@testset "Test examples" begin
    include("snopt_tests.jl")
end
