using SparseArrays

@testset "Invalid high-level inputs fail before loading SNOPT" begin
    saved_library = SNOPT.libsnopt7
    try
        @eval SNOPT libsnopt7 = ""
        f(x) = sum(abs2, x)
        g!(g, x) = (g .= 2 .* x)
        for kwargs in ((lb = [2.0], ub = [1.0]),
                       (lb = reshape([0.0], 1, 1),),
                       (eval_con = (c, x) -> (c[1] = x[1]),
                        eval_jac = (j, x) -> (j[1] = 1.0),
                        lcon = [2.0], ucon = [1.0]))
            @test_throws ArgumentError snopt(f, g!, [0.0]; kwargs...)
        end
        basis = SnoptBasis(Int32[0, 0], 0, 1, 1)
        @test_throws ArgumentError snopt(f, g!, [0.0]; start = "invalid", basis)
        @test SNOPT.prepare_start_basis(basis, " Warm ", 1, 1) == (basis.hs, 0)
        for name in ("123456789", "ééééé")
            @test_throws ArgumentError snopt(f, g!, [0.0]; name)
        end
        for (hs, nS) in ((Int32[0, 0], -1),
                         (Int32[0, 0], 3),
                         (Int32[9, 0], 0),
                         (Int32[4, 0], 0),
                         (Int32[5, 0], 0),
                         (Int32[2, 0], 0))
            basis = SnoptBasis(hs, nS, 1, 1)
            @test_throws ArgumentError snopt(f, g!, [0.0]; start = "Warm", basis)
        end
    finally
        @eval SNOPT libsnopt7 = $saved_library
    end
end

@testset "Library-free input and option contracts" begin
    for x0 in (Float64[], [NaN], [Inf], [-Inf])
        @test_throws ArgumentError snopt(sum, (g, x) -> fill!(g, 1.0), x0)
    end
    @test SNOPT.bound_vector(nothing, 2, -1.0e20, "lb") == fill(-1.0e20, 2)
    @test SNOPT.bound_vector(-Inf, 2, 0.0, "lb") == fill(-1.0e20, 2)
    @test SNOPT.bound_vector((0, 1), 2, 0.0, "lb") == [0.0, 1.0]
    for invalid in ([NaN], [0.0, 1.0])
        @test_throws ArgumentError SNOPT.bound_vector(invalid, 1, 0.0, "lb")
    end
    @test SNOPT.option_keyword(:major_print_level) == "major print level"
    @test SNOPT.option_keyword(" Major print level ") == "Major print level"
    for key in ("", "  ", 1)
        @test_throws ArgumentError SNOPT.option_keyword(key)
    end
    for J in (spzeros(2, 3), sparse([1, 2], [1, 3], [0.0, 1.0], 2, 3))
        converted = SNOPT.jacobian_sparsity32(J, 2, 3)
        @test converted isa SparseMatrixCSC{Float64, Int32}
        @test converted.colptr == J.colptr
        @test converted.rowval == J.rowval
        @test converted.nzval == J.nzval
    end
    @test_throws ArgumentError SNOPT.SnoptWorkspace(499, 500)
    @test_throws ArgumentError SNOPT.SnoptWorkspace(500, 499)
end

@testset "Jacobian storage is checked before Fortran calls" begin
    saved_library = SNOPT.libsnopt7
    ws = SNOPT.SnoptWorkspace(500, 500)
    try
        @eval SNOPT libsnopt7 = ""
        for corrupt! in (J -> (J.rowval[1] = 0),
                         J -> (J.colptr[end] = 3),
                         J -> empty!(J.nzval))
            J = sparse(Int32[1], Int32[1], [1.0], 1, 1)
            corrupt!(J)
            prob = SnoptB(ws, 1, 1, 1, 1, zeros(2), zeros(2), ones(2),
                          zeros(Int32, 2), J, 0.0, 0, Float64[], nothing, nothing)
            @test_throws ArgumentError snopt!(prob)
            probc = SnoptC(ws, 1, 1, 1, 1, zeros(2), zeros(2), ones(2),
                           zeros(Int32, 2), J, 0.0, 0, Float64[], nothing)
            @test_throws ArgumentError snoptc!(probc)
            @test_throws ArgumentError snopt(x -> x[1]^2, (g, x) -> (g[1] = 2x[1]), [0.0];
                eval_con = (c, x) -> (c[1] = x[1]),
                eval_jac = (j, x) -> (j[1] = 1.0), lcon = [0.0], ucon = [1.0], J)
        end

        malformed = (
            SparseMatrixCSC{Float64, Int32}(1, 1, Int32[0, 2], Int32[1], [1.0]),
            SparseMatrixCSC{Float64, Int32}(2, 1, Int32[1, 3], Int32[1, 1], ones(2)),
            SparseMatrixCSC{Float64, Int32}(2, 1, Int32[1, 3], Int32[2, 1], ones(2)),
            SparseMatrixCSC{Float64, Int32}(2, 3, Int32[1, 3, 2, 3],
                                            Int32[1, 2], ones(2)),
        )
        for J in malformed
            @test_throws ArgumentError SNOPT.validate_jacobian_storage(J)
        end
    finally
        close(ws)
        @eval SNOPT libsnopt7 = $saved_library
    end
end
