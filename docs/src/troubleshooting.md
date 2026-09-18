```@meta
CurrentModule = SNOPT
```

# Troubleshooting

Start with the library values that SNOPT.jl sees:

```julia
using SNOPT

SNOPT.has_snopt()
SNOPT.libsnopt7
SNOPT.find_snopt_lib()
```

`SNOPT.libsnopt7` is fixed when the module loads. Restart Julia after changing
`SNOPTDIR` or a platform library path.

## `has_snopt()` returns `false`

Confirm that `SNOPTDIR` names the directory that contains `libsnopt7`, rather
than the library file itself. Check that the current process can read the file.
Then restart Julia and run the diagnostic calls above.

If `find_snopt_lib()` returns a path but `has_snopt()` is false, the dynamic
loader could not load that file or the required C symbols are absent. On Linux,
`ldd /path/to/libsnopt7.so` lists missing shared-library dependencies.

## Missing `f_*` interface symbols

SNOPT.jl requires the C interface supplied by
[`snopt-interface`](https://github.com/snopt/snopt-interface). The library must
export functions such as `f_sninitx`, `f_snoptb`, and `f_snkera`. A library
built only from the Fortran sources does not provide these functions.

Use a distribution that includes the C interface, or rebuild SNOPT with
`snopt-interface` enabled.

## Windows library does not load

SNOPT.jl uses Julia's MinGW calling convention on Windows. Use a MinGW-built
`libsnopt7.dll`; the Intel compiler build supplied for Visual Studio is not ABI
compatible. The application binary interface (ABI) defines how compiled code
passes values between the library and Julia.

Windows Subsystem for Linux is an alternative when only a Linux library is
available.

## Unsupported architecture or version

Apple Silicon is not currently supported. Intel macOS is expected to work but
is not part of the test matrix. Linux and MinGW Windows builds are supported.

SNOPT.jl reads iteration and timing fields from the SNOPT 7.7 workspace layout.
Use SNOPT 7.7 unless you have verified another version against the package test
suite. A different version can solve correctly while reporting incorrect
statistics.
