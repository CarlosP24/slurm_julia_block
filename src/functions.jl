function mwe()
    lat = LP.honeycomb();
    model= @hopping((; t = 2.7) -> t*I);
    h = lat |> model

    g = h |> greenfunction()

    trng = range(0, 5, length = 100)
    ωrng = range(-1, 1, length = 100) .+ 1e-3im

    pts = Iterators.product(ωrng, trng)
    LDOS = @showprogress pmap(pts) do pt 
        ω, t = pt
        return ldos(g[cells = (1, 1)])(ω; t)
    end
    return LDOS
end