using Documenter
using SNOPT

DocMeta.setdocmeta!(SNOPT, :DocTestSetup, :(using SNOPT); recursive = true)

makedocs(;
    modules = [SNOPT],
    authors = "Alex Pascarella",
    sitename = "SNOPT.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://EllissoideRotondo.github.io/SNOPT.jl",
        edit_link = "main",
    ),
    pages = [
        "Home" => "index.md",
        "Installation" => "installation.md",
        "High-level interface" => "interface.md",
        "Low-level interface" => "lowlevel.md",
        "Examples" => "examples.md",
        "Troubleshooting" => "troubleshooting.md",
        "API reference" => "api.md",
    ],
    # Every exported symbol must appear in an @docs block.
    checkdocs = :exports,
    # Hosted CI renders the docs without SNOPT. The self-hosted solver job sets
    # SNOPT_DOCTESTS=true and executes the solver examples.
    doctest = get(ENV, "SNOPT_DOCTESTS", "false") == "true",
)

if get(ENV, "SNOPT_DOCS_DEPLOY", "true") == "true"
    deploydocs(;
        repo = "github.com/EllissoideRotondo/SNOPT.jl",
        devbranch = "main",
        push_preview = true,
    )
end
