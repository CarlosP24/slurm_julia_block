using Pkg
Pkg.activate(".")
Pkg.instantiate()

using Distributed

# Setup workers per node (this is a ñapa, surely it's improvable)
nodes = open("machinefile") do f
    read(f, String)
    end
nodes = split(nodes, "\n")
pop!(nodes)
nodes = string.(nodes)
my_procs = map(x -> (x, :auto), nodes)
# :auto should set the optimal number of workers per node, change for a fixed number if needed

addprocs(my_procs; exeflags="--project", enable_threaded_blas = false)

@everywhere begin
    #include here your code
end

# Run your code

# EOF
rmprocs(workers()...)