using Distributed
@everywhere begin
    using Pkg; Pkg.activate(".")
    Pkg.instantiate(); Pkg.precompile()
end

@everywhere begin
    using Quantica
    include("src/functions.jl")
end

LDOS = mwe()
save("LDOS.jld2", "LDOS", LDOS)

rmprocs(workers()...)