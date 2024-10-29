## Load
# @everywhere begin
#     using Quantica
#     using ProgressMeter
#     include("functions.jl")
# end
using JLD2
@everywhere begin
    using Quantica
    using ProgressMeter
    include("functions.jl")
end

## Run 
LDOS = mwe()
save("LDOS.jld2", "LDOS", LDOS)