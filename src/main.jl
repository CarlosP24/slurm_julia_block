# using JLD2
# @everywhere begin
#     using Quantica
#     using ProgressMeter
#     include("functions.jl")
# end
include("functions.jl")
## Run 
LDOS = mwe()
save("LDOS.jld2", "LDOS", LDOS)