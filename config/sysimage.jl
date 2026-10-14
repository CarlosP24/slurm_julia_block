# System image of this project for the cluster jobs (SYSIMAGE = 1 in config/project.mk).
# Run by config/prologue.sh on the login node; prints the path of the image, and nothing
# else, on stdout. The image holds every package of Project.toml compiled for
# JULIA_CPU_TARGET, plus the methods that config/sysimage_workload.jl (optional, per
# project: a tiny version of a real run) compiles. It is rebuilt only when the Manifest, the
# Julia version, the CPU target or the workload change; older images are deleted.
#
# Without a workload the image only saves the package loading time (seconds). With one, it
# also saves each worker's first-call compilation of the workload's methods.
using Pkg, TOML

project_dir = dirname(Base.active_project())
manifest = joinpath(project_dir, "Manifest.toml")
workload = joinpath(project_dir, "config", "sysimage_workload.jl")
cpu_target = get(ENV, "JULIA_CPU_TARGET", "native")

key = string(hash((read(manifest, String), string(VERSION), cpu_target,
    isfile(workload) ? read(workload, String) : "")); base = 16)
dir = joinpath(first(DEPOT_PATH), "sysimages")
path = joinpath(dir, "sys_$key.so")

packages = Symbol.(collect(keys(TOML.parsefile(Base.active_project())["deps"])))

# called through invokelatest: PackageCompiler is loaded after this file started (world age)
function build()
    mkpath(dir)
    tmp = joinpath(dir, "tmp_$key.so")
    PackageCompiler.create_sysimage(packages; project = project_dir, sysimage_path = tmp,
        cpu_target, precompile_execution_file = isfile(workload) ? [workload] : String[])
    mv(tmp, path; force = true)
    for f in readdir(dir; join = true)
        f != path && startswith(basename(f), "sys_") && rm(f; force = true)
    end
end

if !isfile(path)
    redirect_stdout(stderr) do
        println("Building the system image (once per environment, several minutes)...")
        isfile(workload) || println("No config/sysimage_workload.jl: the image will only " *
            "save package loading, not the first-call compilation of your code.")
        # PackageCompiler lives in its own environment, never in the project's
        Pkg.activate(joinpath(first(DEPOT_PATH), "environments", "sysimage_builder"); io = devnull)
        haskey(Pkg.project().dependencies, "PackageCompiler") || Pkg.add("PackageCompiler")
        @eval using PackageCompiler
        Base.invokelatest(build)
    end
end
println(path)
