## Load
# @everywhere begin
#     using Quantica
#     using ProgressMeter
#     include("functions.jl")
# end

using Quantica
using ProgressMeter
include("functions.jl")

## Run 
LDOS = mwe()
save("LDOS.jld2", "LDOS", LDOS)