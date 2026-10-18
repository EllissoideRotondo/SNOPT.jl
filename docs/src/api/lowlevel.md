```@meta
CurrentModule = SNOPT
```

# Low-level API

```@index
Pages = ["lowlevel.md"]
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

## Problem types

```@docs
AbstractSnoptProblem
SnoptA
SnoptB
SnoptProblem
SnoptC
```

## Solve functions

```@docs
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
