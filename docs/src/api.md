```@meta
CurrentModule = SNOPT
```

# API reference

## Solve a problem

```@docs
snopt
SnoptResult
SnoptBasis
SNOPT_STATUS
```

## Monitor a solve

```@docs
SnoptMajorLog
SnoptStopEvent
snopt_no_progress
```

## Workspace and options

```@docs
initialize
SNOPT.SnoptWorkspace
set_option!
read_options
specs_status_message
snmemb
SnoptMemory
```

## Low-level problem types

```@docs
AbstractSnoptProblem
SnoptA
SnoptB
SnoptProblem
SnoptC
snopt!
snopta!
snoptb!
snoptc!
```

## Callback builders

```@docs
make_usrfun_a
make_objfun
make_confun
make_dummy_confun
make_usrfun_c
make_snlog
make_snstop
```

## Library setup

These functions are not exported. Call them as `SNOPT.has_snopt()` and
`SNOPT.find_snopt_lib()`.

```@docs
SNOPT.has_snopt
SNOPT.find_snopt_lib
```

## Index

```@index
Pages = ["api.md"]
```
