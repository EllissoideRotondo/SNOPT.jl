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
        "Getting started" => "getting_started.md",
        "Installation" => "installation.md",
        "How-to guides" => [
            "Set solver options" => "howto/options.md",
            "Monitor and stop a solve" => "howto/monitoring.md",
            "Warm and hot starts" => "howto/warm_start.md",
            "Low-level interface" => "howto/lowlevel.md",
        ],
        "Solver concepts" => "concepts.md",
        "API reference" => [
            "High-level API" => "api/highlevel.md",
            "Monitoring API" => "api/monitoring.md",
            "Low-level API" => "api/lowlevel.md",
        ],
    ],
    # Every exported symbol must appear in an @docs block.
    checkdocs = :exports,
    # The examples need a licensed SNOPT library, so they run wherever one is found.
    # Hosted CI has none and only renders the pages. SNOPT_DOCTESTS overrides the
    # default; the self-hosted job sets it to "true" so a missing library fails.
    doctest = haskey(ENV, "SNOPT_DOCTESTS") ? ENV["SNOPT_DOCTESTS"] == "true" :
              SNOPT.has_snopt(),
)

if get(ENV, "SNOPT_DOCS_DEPLOY", "true") == "true"
    deploydocs(;
        repo = "github.com/EllissoideRotondo/SNOPT.jl",
        devbranch = "main",
        push_preview = true,
    )
end
