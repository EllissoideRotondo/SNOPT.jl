```@meta
CurrentModule = SNOPT
```

# Installation

SNOPT.jl needs two parts: the Julia package, installed with the package manager, and
the SNOPT shared library, available from the SNOPT distributors. This page
explains how to connect the two and how to check the result.

## Requirements

- Julia 1.10 or later.
- A licensed SNOPT 7.7 shared library, `libsnopt7`, that includes the C interface
  from [snopt-interface](https://github.com/snopt/snopt-interface).

SNOPT.jl reads the iteration counts and the solve time from fixed positions in the
SNOPT 7.7 workspace. With another SNOPT version, a solve can be correct while these
values are wrong.

## Install the package

```julia
using Pkg
Pkg.add("SNOPT")
```

To use the development version:

```julia
using Pkg
Pkg.develop(url = "https://github.com/EllissoideRotondo/SNOPT.jl")
```

The package loads without the SNOPT library. In that case
[`SNOPT.has_snopt`](@ref) returns `false`, and each solve throws an error that
explains how to make the library available.

## Make the library available

The library file has a different name on each platform:

| Platform | File name |
| --- | --- |
| Linux | `libsnopt7.so` |
| macOS (Intel) | `libsnopt7.dylib` |
| Windows | `libsnopt7.dll` |

Set the environment variable `SNOPTDIR` to the directory that contains this file.
Do this before you start Julia.

Linux and macOS (bash or zsh):

```bash
export SNOPTDIR=/path/to/snopt/lib
```

Windows (PowerShell):

```powershell
$env:SNOPTDIR = "C:\path\to\snopt\lib"
```

SNOPT.jl looks for the library once, when you load the package. If you change
`SNOPTDIR` later, restart Julia.

Some SNOPT licenses also need the variable `SNOPT_LICENSE`. Follow the instructions
that come with your SNOPT distribution.

### Search order

SNOPT.jl accepts the first library that it can load and that contains all the C
functions it needs. It looks in these places, in this order:

1. The directory in `SNOPTDIR`. If `SNOPTDIR` is set but the library there cannot be
   used, SNOPT.jl shows a warning and continues.
2. The directories in `LD_LIBRARY_PATH` (Linux and macOS), `DYLD_LIBRARY_PATH`
   (macOS) or `PATH` (Windows).
3. The default locations of the system loader, for example `/usr/lib` on Linux.

If a file `libiomp5` (the Intel OpenMP runtime library) is in the same directory as
`libsnopt7`, SNOPT.jl also loads it. If that fails, SNOPT.jl continues without it.

## Check the setup

This command prints the path of the library that SNOPT.jl found. If you installed
SNOPT.jl in a project environment, add `--project=/path/to/project` after `julia`.

```bash
julia -e 'using SNOPT; @assert SNOPT.has_snopt(); println(SNOPT.libsnopt7)'
```

In PowerShell:

```powershell
julia -e "using SNOPT; @assert SNOPT.has_snopt(); println(SNOPT.libsnopt7)"
```

Then solve the first problem in [Getting started](@ref).

## Platform support

| Platform | Status |
| --- | --- |
| Linux | Supported and tested. |
| Windows | Supported with a MinGW build of `libsnopt7.dll`. |
| macOS (Intel) | Expected to work. Not tested. |
| macOS (Apple silicon) | Not supported. |

## Troubleshooting

Start with the values that SNOPT.jl sees:

```julia
using SNOPT

SNOPT.has_snopt()        # true if a usable library was found
SNOPT.libsnopt7          # path of that library, or ""
SNOPT.find_snopt_lib()   # repeat the search now
```

[`SNOPT.find_snopt_lib`](@ref) does not change `SNOPT.libsnopt7`. After you correct
the setup, restart Julia.

### `has_snopt()` returns `false`

- Make sure that `SNOPTDIR` is the directory that contains the library, not the path
  of the library file.
- Make sure that your user can read the file.
- If `find_snopt_lib()` also returns `""`, no directory in the search order contains
  a usable library.

### The library exists but does not load

The system loader cannot load the library, or the library does not contain the C
interface. On Linux, `ldd /path/to/libsnopt7.so` lists the shared libraries that are
missing.

SNOPT.jl needs the C functions from
[snopt-interface](https://github.com/snopt/snopt-interface), for example `f_sninitx`,
`f_snoptb` and `f_snkera`. SNOPT.jl checks for all of them before it accepts a
library. A library built only from the Fortran source does not contain these
functions. Use a SNOPT distribution that includes the C interface, or build SNOPT
again with snopt-interface.

### Windows

SNOPT.jl needs a `libsnopt7.dll` built with MinGW, the GNU compiler for Windows. The
library built with the Intel compiler for Visual Studio passes arguments in a
different way and does not work with SNOPT.jl. If you only have a Linux library, use
the Windows Subsystem for Linux (WSL).
