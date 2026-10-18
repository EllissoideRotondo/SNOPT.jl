```@meta
CurrentModule = SNOPT
```

# Set solver options

SNOPT has more than 100 options, such as tolerances, iteration limits and print
levels. Each option has a name of one or more words, for example
`"Major iterations limit"`. The
[SNOPT option reference](https://ccom.ucsd.edu/~optimizers/docs/snopt/options.html)
gives all names, default values and meanings.

## Pass options to `snopt`

Give `options` as a vector of pairs `name => value`:

```julia
result = snopt(objective, gradient!, x0;
               options = ["Major iterations limit" => 500,
                          "Major optimality tolerance" => 1.0e-8,
                          "Hessian" => "limited memory"])
```

| Part | Allowed values |
| --- | --- |
| Name | A `String`, or a `Symbol` in which `_` stands for a space. |
| Value | An integer, a finite floating-point number, a `String` (passed unchanged) or a `Symbol` (`_` stands for a space). |

Thus `:major_iterations_limit => 500` is the same as
`"Major iterations limit" => 500`, and `:hessian => :limited_memory` is the same as
`"Hessian" => "limited memory"`. SNOPT does not distinguish upper case and lower case
in option names.

SNOPT.jl rejects `true` and `false` as values, because Julia would pass them to SNOPT
as the integers 1 and 0. Use the integer that the SNOPT option reference gives.

An option name that SNOPT does not know, or a value that SNOPT does not accept, throws
an `ArgumentError` before the solve starts.

## Frequently used options

| Option | Effect |
| --- | --- |
| `"Major iterations limit"` | Maximum number of major iterations. |
| `"Iterations limit"` | Maximum total number of minor iterations. |
| `"Major optimality tolerance"` | Tolerance on the optimality conditions. |
| `"Major feasibility tolerance"` | Tolerance on the constraint violation. |
| `"Time limit"` | Maximum CPU time of the solve, in seconds. |
| `"Hessian"` | `"full memory"` or `"limited memory"`. Use limited memory for many variables. |
| `"Verify level"` | `0` to `3`: check the derivatives against finite differences. `-1` turns the check off. |
| `"Major print level"` | `0` writes no iteration table to the log file. |

[Solver concepts](@ref) explains major and minor iterations.

## Write the SNOPT log to a file

By default, SNOPT.jl keeps no SNOPT output. Use these keywords of [`snopt`](@ref) to
keep it:

| Keyword | Default | Content |
| --- | --- | --- |
| `printfile` | `""` | Path of the print file, the full log with one line per iteration. `""` writes no file. |
| `summfile` | `""` | Path of the summary file, a short log of the main events. `""` writes no file. |
| `name` | `"Julia"` | Problem name that SNOPT writes in the log. A name longer than 8 bytes throws an `ArgumentError`. |

```julia
result = snopt(objective, gradient!, x0;
               printfile = "solve.out",
               options = ["Major print level" => 1])
```

When both paths are `""`, SNOPT.jl creates a temporary summary file, because SNOPT
needs one file to write to, and deletes it when the workspace closes. The temporary
directory must therefore be writable; otherwise, pass `summfile`.

## Read options from a specs file

A specs file is a text file that contains SNOPT options, one option on each line,
between the lines `Begin` and `End`:

```text
Begin
   Major iterations limit       500
   Major optimality tolerance   1.0e-8
End
```

[`snopt`](@ref) does not read specs files. With the [Low-level interface](@ref), call
[`read_options`](@ref) on an open workspace:

```julia
initialize("", "") do workspace
    read_options(workspace, "problem.spc")
    # Build and solve a low-level problem with this workspace.
end
```

[`read_options`](@ref) returns `101` when it reads the file without errors.
[`specs_status_message`](@ref) explains the other codes.
