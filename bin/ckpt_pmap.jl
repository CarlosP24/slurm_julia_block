# ckpt_pmap(f, items; name): a pmap for long runs, with
#   * checkpoints: finished chunks are saved in data/.checkpoints/<name>_<key>/, one file
#     every `checkpoint_seconds` (few files: the master's writes block it, and /home is often
#     a network FS), so a run that dies (time limit, node failure, error) resumes from them,
#     losing at most that much work, when called again with the same name and items. The
#     folder is deleted when the run completes;
#   * automatic chunking: chunks are sized on the fly to take about `chunk_seconds` each and
#     shrink near the end so that no worker idles while others finish (no batch_size to
#     tune); `f` is sent once per worker (CachingPool), not with every chunk;
#   * fault tolerance: the chunk of a worker that dies is given to another one;
#   * progress: one log line every `progress_seconds`, with rate and ETA.
# Returns the results with the shape of `items`, as map/pmap do. Drop-in for
#   pmap(f, items; batch_size = ...)  ->  ckpt_pmap(f, items; name = "panel_a")
# Included by bin/launcher.jl on cluster runs; for local runs, include("bin/ckpt_pmap.jl")
# after addprocs.
#
# The checkpoint key hashes `items`, not `f`: after changing the code but not the items,
# pass resume = false (or run with CKPT_RESUME=0), or delete the folder.

# Qualified names only: projects' own packages export names like `serialize` (Quantica)
import Distributed, Serialization, Dates

function ckpt_pmap(f, items; name::AbstractString, chunk_seconds = 20.0,
        checkpoint_seconds = 60.0, progress_seconds = 60.0, dir = joinpath("data", ".checkpoints"),
        resume = get(ENV, "CKPT_RESUME", "1") != "0", cleanup = true, key = nothing)
    xs = collect(items)
    n = length(xs)
    key = something(key, string(hash(sprint(Serialization.serialize, xs)); base = 16))
    cdir = joinpath(dir, "$(name)_$key")
    results = Vector{Any}(undef, n)
    done = falses(n)
    if resume && isdir(cdir)
        for file in readdir(cdir; join = true)
            endswith(file, ".jls") || continue
            idx, vals = Serialization.deserialize(file)
            results[idx] .= vals
            done[idx] .= true
        end
        any(done) && @info "ckpt_pmap $name: resuming from checkpoints" done = count(done) of = n
    elseif isdir(cdir)
        rm(cdir; recursive = true)
    end
    mkpath(cdir)

    todo = findall(!, done)
    nw = Distributed.nworkers()
    pool = Distributed.CachingPool(Distributed.workers())
    g = chunk -> map(f, chunk)
    next = 1                           # next position in todo
    t_item = NaN                       # running estimate of seconds per item
    n0, ndone = count(done), count(done)
    t0 = tlast = time()
    failure = nothing
    pending_idx, pending_vals = Int[], Any[]   # finished, not yet on disk
    tsaved = time()
    @info "ckpt_pmap $name" items = n todo = length(todo) workers = nw checkpoints = cdir

    # guided self-scheduling: ~chunk_seconds per chunk, at most remaining/(2 nw) near the end
    function take_chunk()
        remaining = length(todo) - next + 1
        c = isnan(t_item) ? 1 : round(Int, chunk_seconds / t_item)
        c = clamp(min(c, cld(remaining, 2nw)), 1, remaining)
        idx = todo[next:next+c-1]
        next += c
        return idx
    end

    function save_pending()
        isempty(pending_idx) && return
        file = joinpath(cdir, "part_$(round(Int, 1000 * time()))_$(length(pending_idx)).jls")
        Serialization.serialize(file * ".tmp", (pending_idx, pending_vals))
        mv(file * ".tmp", file; force = true)
        empty!(pending_idx); empty!(pending_vals)
        tsaved = time()
    end

    @sync for _ in 1:nw
        @async while failure === nothing && next <= length(todo)
            idx = take_chunk()
            t = time()
            vals = try
                Distributed.remotecall_fetch(g, pool, xs[idx])
            catch e
                if e isa Distributed.ProcessExitedException
                    @warn "ckpt_pmap $name: a worker died, its chunk goes back to the queue"
                    append!(todo, idx)
                    continue
                end
                failure = e
                break
            end
            dt = (time() - t) / length(idx)
            t_item = isnan(t_item) ? dt : 0.8 * t_item + 0.2 * dt
            results[idx] .= vals
            done[idx] .= true
            append!(pending_idx, idx); append!(pending_vals, vals)
            time() - tsaved > checkpoint_seconds && save_pending()
            ndone += length(idx)
            if time() - tlast > progress_seconds
                tlast = time()
                rate = (ndone - n0) / (tlast - t0)
                @info "ckpt_pmap $name" time = Dates.now() progress = "$ndone/$n" items_per_s =
                    round(rate, sigdigits = 3) eta_min = round((n - ndone) / rate / 60, digits = 1)
            end
        end
    end
    if failure !== nothing              # checkpoints are kept for the next attempt
        save_pending()
        throw(failure)
    end

    cleanup ? rm(cdir; recursive = true) : save_pending()
    @info "ckpt_pmap $name: done" items = n minutes = round((time() - t0) / 60, digits = 1)
    return reshape(map(identity, results), size(xs))
end
