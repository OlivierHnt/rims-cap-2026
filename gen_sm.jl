# Shimizu–Morioka:  x' = y,  y' = x(1-z) - λ y,  z' = x^2 - α z
# Emits the attractor polyline + a contiguous interval-box covering whose cells each carry an
# animation-delay equal to the arc-length fraction where the trajectory first enters them, so the
# boxes light up IN SYNC with the pen drawing the trajectory (linear draw of duration DRAW).
# The dash length (--len) is computed from the ROUNDED coords, so it matches the rendered path
# length exactly -> the trajectory reveals as one continuous arc.
using Printf

function run()
    λ = 0.81; α = 0.375
    f(s) = (s[2], s[1]*(1 - s[3]) - λ*s[2], s[1]^2 - α*s[3])
    function step(s, dt)
        k1 = f(s)
        s2 = s .+ 0.5dt .* k1; k2 = f(s2)
        s3 = s .+ 0.5dt .* k2; k3 = f(s3)
        s4 = s .+ dt   .* k3;  k4 = f(s4)
        s .+ (dt/6) .* (k1 .+ 2 .* k2 .+ 2 .* k3 .+ k4)
    end

    s = (0.8, 0.0, 0.6); dt = 0.004
    raw = Tuple{Float64,Float64}[]
    for i in 1:80_000
        s = step(s, dt)
        i >= 20_000 && push!(raw, (s[1], s[3]))   # project to (x, z)
    end

    NPTS = 2000                                    # trimmed to essentials (smooth shape, lean DOM)
    k = max(1, div(length(raw), NPTS))
    poly = raw[1:k:end]
    xs = first.(poly); zs = last.(poly)
    minx, maxx = extrema(xs); minz, maxz = extrema(zs)

    # fit into hero viewBox (0 0 560 340), preserve aspect
    TX0, TX1, TY0, TY1 = 60, 500, 55, 300
    W, H = TX1 - TX0, TY1 - TY0
    dW, dH = maxx - minx, maxz - minz
    scale = min(W/dW, H/dH) * 0.95
    cxd, czd = (minx+maxx)/2, (minz+maxz)/2
    tcx, tcy = (TX0+TX1)/2, (TY0+TY1)/2
    sx(x) = tcx + (x - cxd)*scale
    sy(z) = tcy - (z - czd)*scale

    # rounded SVG coords — the same numbers the browser parses, so --len is exact
    Pr = [(round(sx(x); digits=1), round(sy(z); digits=1)) for (x, z) in poly]
    cum = zeros(Float64, length(Pr))
    for i in 2:length(Pr)
        cum[i] = cum[i-1] + hypot(Pr[i][1]-Pr[i-1][1], Pr[i][2]-Pr[i-1][2])
    end
    total = cum[end]
    d = "M " * join([@sprintf("%.1f %.1f", p[1], p[2]) for p in Pr], " L ")

    # CSS timing — MUST match the .attractor animation in the stylesheet
    START = 0.6; DRAW = 10.0

    # contiguous covering: first arc-length fraction at which the polyline enters each cell
    NX = 30; h = dW / NX
    firstfrac = Dict{Tuple{Int,Int},Float64}()
    for i in 1:length(poly)
        cell = (floor(Int, (poly[i][1]-minx)/h), floor(Int, (poly[i][2]-minz)/h))
        haskey(firstfrac, cell) || (firstfrac[cell] = cum[i] / total)
    end

    rects = String[]
    for (cell, frac) in sort(collect(firstfrac); by = kv -> kv[2])
        ix, iz = cell
        x0 = sx(minx + ix*h);       x1 = sx(minx + (ix+1)*h)
        ytop = sy(minz + (iz+1)*h); ybot = sy(minz + iz*h)
        delay = START + frac*DRAW
        push!(rects, @sprintf("  <rect x=\"%.1f\" y=\"%.1f\" width=\"%.1f\" height=\"%.1f\" style=\"animation-delay:%.2fs\"/>",
                              x0, ytop, x1-x0, ybot-ytop, delay))
    end
    @printf("poly=%d  cells=%d  len=%.1f  draw=%.1fs\n", length(poly), length(rects), total, DRAW)

    frag = "<g class=\"cover\">\n" * join(rects, "\n") * "\n</g>\n" *
           @sprintf("<path class=\"attractor\" style=\"--len:%.1f\" d=\"%s\"/>", total, d)
    open("/tmp/sm_fragment.txt", "w") do io; write(io, frag); end
    @printf("wrote /tmp/sm_fragment.txt (%d bytes)\n", length(frag))
end

run()
