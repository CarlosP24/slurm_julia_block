## Load
# @everywhere begin
#     using Quantica
#     using ProgressMeter
#     include("functions.jl")
# end

@everywhere begin
    using Quantica
    using ProgressMeter
    include("functions.jl")
end

## Run 
LDOS = mwe()
save("LDOS.jld2", "LDOS", LDOS)