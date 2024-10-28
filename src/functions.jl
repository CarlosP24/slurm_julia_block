function mwe()
    lat = LP.honeycomb();
    model= @hopping((; t = 2.7) -> t*I);
    h = lat |> model

    g = greenfunction()
    ρ = ldos(g[cells = (1,)])
    trng = range(0, 5, length = 100)
    ωrng = range(-1, 1, length = 100) .+ 1e-3im

    pts = Iterators.product(ωrng, trng)
    LDOS = pmap(pts) do pt 
        ω, t = pt
        return ρ(ω; t)
    end
    return LDOS
end