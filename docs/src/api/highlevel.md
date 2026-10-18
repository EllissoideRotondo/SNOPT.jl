```@meta
CurrentModule = SNOPT
```

# High-level API

```@index
Pages = ["highlevel.md"]
```

## Solve a problem

```@docs
snopt
SnoptResult
SnoptBasis
```

## Status

```@docs
SnoptStatus
SNOPT.status_from_code
```

## Library setup

These functions are not exported. Call them as `SNOPT.has_snopt()` and
`SNOPT.find_snopt_lib()`.

```@docs
SNOPT.has_snopt
SNOPT.find_snopt_lib
```
