@everywhere begin
    include("functions.jl")
end
## Run 
LDOS = mwe()
save("LDOS.jld2", "LDOS", LDOS)