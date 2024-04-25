using StbScratch
using Documenter

DocMeta.setdocmeta!(StbScratch, :DocTestSetup, :(using StbScratch); recursive=true)

makedocs(;
    modules=[StbScratch],
    authors="Graham Stark",
    repo="https://github.com/grahamstark/StbScratch.jl/blob/{commit}{path}#{line}",
    sitename="StbScratch.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://grahamstark.github.io/StbScratch.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/grahamstark/StbScratch.jl",
    devbranch="main",
)
