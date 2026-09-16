@testset "Workspace safety" begin
    @testset "Active solves reject workspace reentry" begin
        for (label, operation) in (
            ("initialize", ws -> SNOPT.initialize("", "")),
            ("close", close),
            ("free!", SNOPT.free!),
            ("integer option", ws -> SNOPT.set_option!(ws, "Major print level", 0)),
            ("real option", ws -> SNOPT.set_option!(ws, "Major optimality tolerance", 1e-6)),
            ("string option", ws -> SNOPT.set_option!(ws, "Hessian limited memory")),
            ("memory estimate", ws -> SNOPT.snmemb(ws, 1, 1, 0, 0, 0, 1, 0)),
            ("nested solve", ws -> SNOPT.snopt(x -> sum(abs2, x),
                (g, x) -> (g .= 2 .* x), [1.0])),
        )
            @testset "$label" begin
                ws = SNOPT.initialize("", "")
                callbacks = SNOPT.ActiveSnoptBCallbacks(nothing, nothing)
                try
                    lock(SNOPT.SNOPT_LOCK) do
                        SNOPT.with_active_snopt_callbacks(ws, callbacks) do
                            @test_throws ArgumentError operation(ws)
                            @test isopen(ws)
                        end
                    end
                finally
                    close(ws)
                    SNOPT.close_active_workspace!()
                end
            end
        end
    end

    @testset "Finalizer cannot close an active solve" begin
        ws = SNOPT.initialize("", "")
        callbacks = SNOPT.ActiveSnoptBCallbacks(nothing, nothing)
        try
            SNOPT.with_active_snopt_callbacks(ws, callbacks) do
                finalize(ws)
                @test isopen(ws)
            end
        finally
            close(ws)
            SNOPT.close_active_workspace!()
        end
    end

    @testset "Workspace operations wait for the active operation" begin
        for operation in (close, SNOPT.free!,
                          ws -> SNOPT.set_option!(ws, "Major print level", 0),
                          ws -> SNOPT.set_option!(ws, "Major optimality tolerance", 1e-6),
                          ws -> SNOPT.set_option!(ws, "Hessian limited memory"),
                          ws -> SNOPT.apply_options!(ws, ["Major print level" => 0]),
                          ws -> SNOPT.snmemb(ws, 1, 1, 0, 0, 0, 1, 0))
            ws = SNOPT.initialize("", "")
            started = Channel{Nothing}(1)
            pending = nothing
            lock(SNOPT.SNOPT_LOCK)
            try
                pending = @async begin
                    put!(started, nothing)
                    operation(ws)
                end
                take!(started)
                yield()
                @test !istaskdone(pending)
                @test isopen(ws)
            finally
                unlock(SNOPT.SNOPT_LOCK)
            end
            wait(pending)
            close(ws)
            @test !isopen(ws)
        end
    end

    @testset "Callback reentry errors leave subsequent solves usable" begin
        objective(x) = sum(abs2, x)
        gradient!(g, x) = (g .= 2 .* x)
        @test_throws ArgumentError SNOPT.snopt(objective, gradient!, [1.0];
            snlog=event -> SNOPT.initialize("", ""))
        @test SNOPT.active_snopt_callback_count() == 0
        result = SNOPT.snopt(objective, gradient!, [1.0])
        @test result.status == 1
        @test result.x ≈ [0.0] atol=1e-6
    end

    @testset "Uninitialized workspaces retain finalizer cleanup" begin
        ws = SNOPT.SnoptWorkspace(500, 500)
        path, io = mktemp()
        close(io)
        push!(ws.tempfiles, path)
        finalize(ws)
        @test !isopen(ws)
        @test !isfile(path)
        @test isempty(ws.tempfiles)
        @test close(ws) === nothing
    end
end
