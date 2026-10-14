# Install the environment pinned by Project.toml + Manifest.toml and precompile it.
# Never resolves or upgrades: a run always uses the versions of the Manifest, or fails.
# If it fails, fix the environment locally (julia --project -e 'using Pkg; Pkg.instantiate()'),
# commit Manifest.toml and deploy again.
using Pkg

try
    println("Instantiating environment...")
    Pkg.instantiate()
    println("Precompiling packages...")
    Pkg.precompile()
    println("Environment setup completed.")
catch e
    println(stderr, "Environment setup failed: ", sprint(showerror, e))
    println(stderr, "The Manifest is not changed on the cluster: fix it locally and deploy again.")
    exit(1)
end
