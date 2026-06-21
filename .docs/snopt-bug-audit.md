# SNOPT Bug Audit

Date: 2026-06-15

Scope:
- Package audited: `/home/alex/projects/code/SNOPT`.
- This audit targets the low-level `SNOPT` package, not the `OptimizationSNOPT` wrapper.
- The checkout was dirty before this audit. Existing modified files were treated as user-owned current code.
- Source code was not edited. This file is the only audit artifact written by this pass.

Baseline verification:
- `julia --project=. -e 'import Pkg; Pkg.test(; coverage=false)'` passed: 179 tests.
- The test run warned that `Manifest.toml` was resolved with Julia 1.9.4 and that project dependencies or compat requirements changed since resolution.
- SNOPT library used locally: `/usr/lib/libsnopt7.so`.

Pre-existing dirty worktree at audit start:
- `Project.toml`
- `src/SNOPT.jl`
- `src/callbacks.jl`
- `src/raw_api.jl`
- `test/snopt_tests.jl`

## Findings

### 1. Too-small workspaces can segfault Julia during `initialize`

Severity: Critical

Affected code:
- `src/types.jl:22-31` accepts any positive `leniw` and `lenrw`.
- `src/workspace.jl:172-190` calls `f_sninitx`, ignores its insufficient-storage condition, then calls `reset_snopt_defaults!` on the same undersized work arrays.
- `src/workspace.jl:12-22` calls SNOPT option machinery on those work arrays.

Impact:
- A public API call can crash the Julia process instead of throwing a Julia exception.
- Slightly undersized workspaces are also returned as open workspaces even after SNOPT prints an initialization failure.

Repro that segfaulted this audit process:

```bash
julia --project=. -e 'using SNOPT; for dims in ((1,1),(10,10),(1000,1),(1,1000)); try; ws=initialize("", "", dims...); println((dims=dims, ok=true, isopen=isopen(ws), status=ws.status)); close(ws); catch e; println((dims=dims, ok=false, error=typeof(e), msg=sprint(showerror,e))); end; end'
```

Observed before the segfault:

```text
SNINIT EXIT  80 -- insufficient storage allocated
SNINIT INFO  81 -- work arrays must have at least 500 elements
signal 11 (128): Segmentation fault
```

Less extreme undersizing is also accepted as an open workspace:

```bash
julia --project=. -e 'using SNOPT; for dims in ((499,500),(500,499),(500,500)); try; ws=initialize("", "", dims...); println((dims=dims, ok=true, isopen=isopen(ws), status=ws.status)); close(ws); catch e; println((dims=dims, ok=false, error=typeof(e), msg=sprint(showerror,e))); end; end'
```

Observed:

```julia
(dims = (499, 500), ok = true, isopen = true, status = 0)
(dims = (500, 499), ok = true, isopen = true, status = 0)
(dims = (500, 500), ok = true, isopen = true, status = 0)
```

Expected:
- Reject workspaces below SNOPT's minimum before any `ccall`, or detect SNOPT initialization failure and throw.

### 2. Closed workspaces can still be used for options, memory estimates, and solves

Severity: High

Affected code:
- `src/workspace.jl:25-55` sets `prob.finalized = true` in `free!`.
- `src/options.jl:63-97`, `src/memory.jl:10-27`, and `src/raw_api.jl:34-333` do not check `isopen(ws)` before calling SNOPT.

Impact:
- A workspace that reports `isopen(ws) == false` can still drive SNOPT calls.
- This is a use-after-finalize API hole. It is especially dangerous because SNOPT has global Fortran state.

Repro:

```bash
julia --project=. -e 'using SNOPT; ws=initialize("", ""); close(ws); println((isopen=isopen(ws), finalized=ws.finalized)); for action in (:set_option, :snmemb); try; if action===:set_option; r=set_option!(ws,"Major print level",0); else; r=snmemb(ws,1,1,1,0,0,1,0); end; println((action=action, ok=true, result=r, isopen=isopen(ws), status=ws.status)); catch e; println((action=action, ok=false, error=typeof(e), msg=sprint(showerror,e), isopen=isopen(ws), status=ws.status)); end; end'
```

Observed:

```julia
(isopen = false, finalized = true)
(action = :set_option, ok = true, result = 0, isopen = false, status = 0)
(action = :snmemb, ok = true, result = SnoptMemory(104, 20594, 10591), isopen = false, status = 104)
```

A closed workspace can also solve:

```bash
julia --project=. -e 'using SNOPT, SparseArrays; ws=initialize("", ""); close(ws); obj=make_objfun(x->(x[1]-1)^2,(g,x)->(g[1]=2*(x[1]-1)),ws.iw); conf=make_dummy_confun(); n=1; m=1; x=[0.0;0.0]; bl=[-10.0;-1e20]; bu=[10.0;1e20]; hs=zeros(Int32,2); J=SparseMatrixCSC{Float64,Int32}(1,n,Int32[1,2],Int32[1],Float64[0.0]); prob=SnoptB(ws,n,0,m,n,x,bl,bu,hs,J,0.0,0,Float64[],obj,conf); try; status=snopt!(prob); println((ok=true,status=status,isopen=isopen(ws),x=prob.x,obj=prob.obj_val,ws_status=ws.status)); catch e; println((ok=false,error=typeof(e),msg=sprint(showerror,e),isopen=isopen(ws),ws_status=ws.status)); end'
```

Observed:

```julia
(ok = true, status = 1, isopen = false, x = [1.0, 0.0], obj = 0.0, ws_status = 1)
```

Expected:
- All public operations requiring a live workspace should reject finalized workspaces.

### 3. Standalone `snmemb(...)` and high-level `snopt(...)` silently close an existing user workspace

Severity: High

Affected code:
- `src/memory.jl:38-48` allocates a temporary workspace via `initialize(...)`.
- `src/workspace.jl:172-177` calls `close_active_workspace!()` inside every `initialize(...)`.
- `src/high_level.jl:170-172` calls standalone `snmemb(...)` as part of every high-level `snopt(...)` solve.

Impact:
- A caller can hold an open manual workspace, call `snmemb(...)` or `snopt(...)`, and find their workspace finalized behind their back.
- This breaks workspace ownership expectations and combines badly with finding #2, because the stale workspace can still be used afterward.

Repro:

```bash
julia --project=. -e 'using SNOPT; ws=initialize("", ""); before=isopen(ws); memory=snmemb(1,1,1,0,0,1,0; options=["Major print level"=>0,"Minor print level"=>0]); println((before=before, after=isopen(ws), finalized=ws.finalized, memory=memory)); result=snopt(x->(x[1]-1)^2,(g,x)->(g[1]=2*(x[1]-1)), [0.0]; options=["Major print level"=>0,"Minor print level"=>0]); println((after_snopt=isopen(ws), result_status=result.status, result_x=result.x))'
```

Observed:

```julia
(before = true, after = false, finalized = true, memory = SnoptMemory(104, 20594, 10591))
(after_snopt = false, result_status = 1, result_x = [1.0])
```

Expected:
- Temporary workspaces should not implicitly close caller-owned workspaces, or this single-active-workspace policy should be explicit and enforced so stale workspaces cannot be reused.

### 4. `snmemb` accepts negative dimensions and returns successful memory estimates

Severity: High

Affected code:
- `src/memory.jl:10-27` passes `m`, `n`, `neJ`, `negCon`, `nnCon`, `nnObj`, and `nnJac` directly to `f_snmem` without validating nonnegative/positive invariants.

Impact:
- Invalid problem dimensions return `SnoptMemory(104, ...)`, which the package treats as a successful estimate.
- Callers can build downstream workspaces using nonsensical memory calculations.

Repro:

```bash
julia --project=. -e 'using SNOPT; ws=initialize("", ""); for args in ((-1,1,1,0,0,1,0),(1,-1,1,0,0,1,0),(1,1,-1,0,0,1,0),(1,1,1,-1,0,1,0)); try; m=snmemb(ws,args...); println((args=args, ok=true, memory=m, status=ws.status)); catch e; println((args=args, ok=false,error=typeof(e),msg=sprint(showerror,e),status=ws.status)); end; end'
```

Observed:

```julia
(args = (-1, 1, 1, 0, 0, 1, 0), ok = true, memory = SnoptMemory(104, 20496, 10521), status = 104)
(args = (1, -1, 1, 0, 0, 1, 0), ok = true, memory = SnoptMemory(104, 20462, 10520), status = 104)
(args = (1, 1, -1, 0, 0, 1, 0), ok = true, memory = SnoptMemory(104, 20594, 10591), status = 104)
(args = (1, 1, 1, -1, 0, 1, 0), ok = true, memory = SnoptMemory(104, 20594, 10587), status = 104)
```

Expected:
- Reject negative dimensions before `ccall`.
- Enforce `m > 0`, `n > 0`, `neJ >= 0`, `negCon >= 0`, `nnCon >= 0`, `nnObj >= 0`, `nnJac >= 0`, and consistency constraints between them.

### 5. High-level `snopt(...; callback=...)` ignores `false` returned during preflight callbacks

Severity: Medium-High

Affected code:
- `src/high_level.jl:94-117` calls `call_progress(callback, event)` during preflight and ignores its return value.
- `src/callbacks.jl:497-502` documents that returning `false` requests termination.
- `src/high_level.jl:134-135` documents callback use for early termination, but preflight events do not honor it.

Impact:
- User callback semantics are inconsistent. Returning `false` from the first callback event can be ignored, and the solve can continue to success.

Repro:

```bash
julia --project=. -e 'using SNOPT; eval_obj(x)=(x[1]-1)^2; eval_grad(g,x)=(g[1]=2*(x[1]-1)); calls=Ref(0); cb=event->begin calls[] += 1; calls[] != 1 end; result=snopt(eval_obj, eval_grad, [0.0]; options=["Major print level"=>0,"Minor print level"=>0], callback=cb); println((status=result.status, status_symbol=result.status_symbol, calls=calls[], x=result.x, obj=result.objective))'
```

Observed:

```julia
(status = 1, status_symbol = :Solve_Succeeded, calls = 5, x = [1.0], obj = 0.0)
```

Expected:
- Either do not call user progress callbacks during preflight, or honor `false` consistently by stopping before the solve.

### 6. High-level `snopt(...)` accepts `NaN` inputs and lets SNOPT return invalid or extreme results

Severity: Medium

Affected code:
- `src/high_level.jl:3-22` converts inputs to `Float64` but does not reject `NaN`.
- `src/high_level.jl:154-158` accepts `x0`, `lb`, and `ub` after conversion.
- `src/high_level.jl:61-80` also accepts `NaN` constraint bounds.

Impact:
- Invalid numerical inputs become SNOPT statuses such as `Invalid_Problem_Definition` or `Numerical_Difficulties` instead of clear Julia validation errors.
- With `x0 = [NaN]`, the result contained `x = [-1.0e20]` and `objective = 1.0e40`.

Repro:

```bash
julia --project=. -e 'using SNOPT; for kwargs in ((;lb=[NaN]), (;ub=[NaN]), (;x0=[NaN])); try; if haskey(kwargs,:x0); result=snopt(x->(x[1]-1)^2,(g,x)->(g[1]=2*(x[1]-1)), kwargs.x0; options=["Major print level"=>0,"Minor print level"=>0]); else; result=snopt(x->(x[1]-1)^2,(g,x)->(g[1]=2*(x[1]-1)), [0.0]; kwargs..., options=["Major print level"=>0,"Minor print level"=>0]); end; println((kwargs=kwargs, ok=true, status=result.status, symbol=result.status_symbol, x=result.x, obj=result.objective)); catch e; println((kwargs=kwargs, ok=false, error=typeof(e), msg=sprint(showerror,e))); end; end'
```

Observed:

```julia
(kwargs = (lb = [NaN],), ok = true, status = 91, symbol = :Invalid_Problem_Definition, x = [0.0], obj = 0.0)
(kwargs = (ub = [NaN],), ok = true, status = 91, symbol = :Invalid_Problem_Definition, x = [0.0], obj = 0.0)
(kwargs = (x0 = [NaN],), ok = true, status = 41, symbol = :Numerical_Difficulties, x = [-1.0e20], obj = 1.0e40)
```

Expected:
- Reject `NaN` in `x0`, bounds, and constraint bounds before calling SNOPT.

### 7. Direct `set_option!` accepts non-finite and invalid tolerance values

Severity: Medium

Affected code:
- `src/options.jl:87-97` sends any `Float64` value directly to `f_snsetr`.
- `src/options.jl:23-27` rejects non-finite floats only for the vector-of-pairs `apply_options!` path, not the direct `set_option!` path.
- Neither path validates positive-only tolerance semantics.

Impact:
- Users can set `NaN`, `Inf`, negative, or zero tolerances and receive `0` success from `set_option!`.
- A simple solve still reports success after these invalid values, making the bad option hard to notice.

Repro:

```bash
julia --project=. -e 'using SNOPT; ws=initialize("", ""); for value in (NaN, Inf, -1.0, 0.0); try; r=set_option!(ws,"Major feasibility tolerance",Float64(value)); println((value=value, ok=true, result=r)); catch e; println((value=value, ok=false, error=typeof(e), msg=sprint(showerror,e))); end; end'
```

Observed:

```julia
(value = NaN, ok = true, result = 0)
(value = Inf, ok = true, result = 0)
(value = -1.0, ok = true, result = 0)
(value = 0.0, ok = true, result = 0)
```

The pair API still accepts negative and zero tolerance values:

```bash
julia --project=. -e 'using SNOPT; ws=initialize("", ""); for opts in (["Major feasibility tolerance"=>-1.0], ["Major feasibility tolerance"=>0.0]); try; r=SNOPT.apply_options!(ws, opts); println((opts=opts, ok=true)); catch e; println((opts=opts, ok=false,error=typeof(e),msg=sprint(showerror,e))); end; end; close(ws)'
```

Observed:

```julia
(opts = ["Major feasibility tolerance" => -1.0], ok = true)
(opts = ["Major feasibility tolerance" => 0.0], ok = true)
```

Expected:
- Direct and pair-based option APIs should share validation for finite values and known positive-only tolerances.

### 8. CI can pass while running zero solver tests

Severity: Medium

Affected code:
- `.github/workflows/CI.yml:28-29` runs build and tests on GitHub-hosted runners.
- `test/runtests.jl:4-7` exits with code `0` when `SNOPT.has_snopt()` is false.
- The workflow does not install or configure `libsnopt7`.

Impact:
- CI likely passes without exercising any of the 179 solver assertions.
- ABI regressions, callback crashes, and workspace lifecycle bugs can land unnoticed unless tested locally with a licensed library.

Expected:
- Mark no-library CI as an explicit skipped job with a separate local/secret-backed solver job, or fail CI when solver tests are expected but `libsnopt7` is unavailable.

### 9. `Manifest.toml` is stale against the current project and Julia version

Severity: Low

Evidence:
- `Pkg.test` emitted:
  - active manifest resolved with Julia `1.9.4`
  - project dependencies or compat requirements changed since the manifest was last resolved

Impact:
- Reproducibility is weaker and users may see resolver behavior that differs from the checked-in manifest.
- This is not a runtime failure in this environment, but it is a packaging hygiene issue.

### 10. Workspace/threading constraints are not enforced or documented at the API boundary

Severity: Low-Medium

Affected code:
- `src/workspace.jl:1-10` documents SNOPT global Fortran state internally.
- `src/workspace.jl:57-65` has a single active workspace policy.
- `src/callbacks.jl:94-185` uses a global callback registry.
- README does not state that only one solve/workspace should be active per process and that concurrent or nested solves are unsupported.

Impact:
- Users can reasonably assume independent `SnoptWorkspace` objects are independent. They are not.
- The package partly enforces this by closing the previous workspace, but other APIs then permit reuse of the closed workspace, producing inconsistent lifecycle semantics.

Expected:
- Document the one-active-workspace constraint prominently.
- Enforce it with open-workspace checks and clear errors rather than silent finalization.

## Notes on Existing Coverage

The local solver tests are valuable and passed, but they do not currently cover:
- too-small workspace initialization failure or segfault prevention
- operations on finalized workspaces
- active workspace invalidation by standalone `snmemb` and high-level `snopt`
- negative `snmemb` dimensions
- preflight callback return semantics
- `NaN` input validation
- direct `set_option!` non-finite values
- whether CI actually runs solver assertions

