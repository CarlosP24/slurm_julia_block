using Pkg
using TOML

function ensure_package(url::String, pkg_name::String)
    # Read Project.toml to check if the package is listed
    project_file = "Project.toml"
    
    if isfile(project_file)
        project_data = TOML.parsefile(project_file)
        
        # Check if package is in Project.toml
        if haskey(project_data["deps"], pkg_name)
            println("$pkg_name found in Project.toml. Ensuring it is added from URL...")
            Pkg.add(url = url)
        else
            println("$pkg_name is not listed in Project.toml, skipping addition.")
        end
    else
        println("Project.toml not found. Cannot verify package dependencies.")
    end
end

function setup_environment()
    # Ensure FullShell.jl is added only if listed in Project.toml
    ensure_package("https://github.com/CarlosP24/FullShell.jl.git", "FullShell")

    # Proceed with instantiation, resolve, and precompile as before
    try
        println("Attempting to instantiate environment...")
        Pkg.instantiate()
    catch e
        println("Instantiation failed: ", e)
        println("Attempting to resolve dependencies...")

        try
            Pkg.resolve()
            println("Dependencies resolved. Re-attempting instantiation...")
            Pkg.instantiate()
        catch resolve_error
            println("Resolve also failed. Check Project.toml and Manifest.toml files.")
            return
        end
    end

    println("Precompiling packages...")
    Pkg.precompile()
    println("Environment setup completed.")
end

# Run the setup process
try
    setup_environment()
catch e
    exit(1)  # Explicitly set non-zero exit code
end