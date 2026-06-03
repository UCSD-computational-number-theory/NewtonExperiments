using Pkg

project_root = dirname(@__DIR__)
deps_root = dirname(project_root)

repos = [
    ("GPUFiniteFieldMatrices.jl", "https://github.com/UCSD-computational-number-theory/GPUFiniteFieldMatrices.jl.git"),
    ("DeRham.jl", "https://github.com/UCSD-computational-number-theory/DeRham.jl.git")
]

for (dirname, url) in repos
    path = joinpath(deps_root, dirname)
    if !isdir(path)
        run(`git clone --depth 1 --branch main $url $path`)
    end
end

Pkg.develop([Pkg.PackageSpec(path=joinpath(deps_root, dirname)) for (dirname, _) in repos])
Pkg.instantiate()
