# Six-term surfaces for the Table 2 (`table:sparse-surfaces`) replication of
# arxiv:2602.24155 "Newton strata realization for hypersurfaces via explicit
# p-adic cohomology" (Batubara, Garzella, Huang, Mellberg).
#
# Table 2 compares our depth-first reduction policy against [CHK]
# (ToricControlledReduction) on degree-d *surfaces* in P^3 over F_p built from
# exactly six monomial terms.
#
# FOOTGUN — meaning of `n`: in this codebase `n` is the number of variables, so a
# surface in P^3 (dimension 2) is `n = 4`, even though the paper labels Table 2
# "n=3" (ambient projective dimension). Always call these helpers with `n = 4`
# for surfaces. See `fermat_hypersurface(n, d, p)` in DeRham, which builds
# x0^d + ... + x_{n-1}^d.

"""
    random_six_term_surface(n, d, p; rng=Random.default_rng(), max_attempts=100)

Build a smooth degree-`d` hypersurface in `P^(n-1)` over `F_p` with **exactly six
distinct monomial terms**, following the "random deformation of a fixed example"
recipe (paper §5.1, Method 2): start from the Fermat hypersurface and add random
monomials.

Concretely the result is

    x0^d + x1^d + ... + x_{n-1}^d  +  c1 * m1  +  c2 * m2

where `m1, m2` are two *distinct* degree-`d` monomials, neither of them a pure
power `xi^d`, and `c1, c2` are nonzero coefficients in `F_p`. Because the two
extra monomials are distinct from each other and from the `n` Fermat pure powers,
the polynomial has exactly `n + 2` terms; for a surface (`n = 4`) that is six.

Candidate surfaces are rejected and resampled (up to `max_attempts` tries) until
one is **smooth** — checked with `DeRham.issmooth_linalg`, the same controlled-
reduction smoothness test used elsewhere in the repo (e.g. `find_nsmooth`).
Smoothness is required both by our reduction policy and by the toric/[CHK]
comparison (which additionally needs the surface to be nondegenerate w.r.t. its
Newton polytope; that is guarded at the [CHK] timer, see `time_chk`). The *same*
polynomial is fed to both timers.

The construction is deterministic given `rng`, so passing a seeded RNG makes the
generated surface reproducible. Returns the Oscar polynomial. Throws if no smooth
example is found within `max_attempts`.
"""
function random_six_term_surface(n, d, p; rng::Random.AbstractRNG=Random.default_rng(), max_attempts::Int=100)
    base = DeRham.fermat_hypersurface(n, d, p)   # x0^d + ... + x_{n-1}^d, n pure powers
    R = parent(base)
    F = base_ring(R)

    # All degree-d exponent vectors, minus the n pure powers [d,0,..], [0,d,0,..], ...
    exp_vecs = DeRham.gen_exp_vec(n, d)
    pure_powers = Set{Vector{Int}}()
    for i in 1:n
        v = zeros(Int, n)
        v[i] = d
        push!(pure_powers, v)
    end
    candidates = [Vector{Int}(ev) for ev in exp_vecs if !(Vector{Int}(ev) in pure_powers)]

    length(candidates) >= 2 ||
        error("Not enough non-pure-power degree-$d monomials in $n variables to add two distinct terms.")

    for _ in 1:max_attempts
        # Two distinct extra monomials with nonzero coefficients.
        i = rand(rng, 1:length(candidates))
        j = rand(rng, 1:length(candidates))
        while j == i
            j = rand(rng, 1:length(candidates))
        end
        c1 = F(rand(rng, 1:(p - 1)))
        c2 = F(rand(rng, 1:(p - 1)))

        ctx = MPolyBuildCtx(R)
        push_term!(ctx, c1, candidates[i])
        push_term!(ctx, c2, candidates[j])
        f = base + finish(ctx)

        # By construction this is n + 2 terms; assert it before the (costly) smoothness test.
        length(f) == n + 2 || continue

        if DeRham.issmooth_linalg(f)
            return f
        end
    end

    error("Could not find a smooth six-term degree-$d surface in $n variables over F_$p " *
          "within $max_attempts attempts (try a different seed or raise max_attempts).")
end

"""
    time_zeta_depthfirst(f; samples=3) -> Float64

Our-side timing for Table 2: time the full zeta-function computation under the
depth-first reduction policy with fast evaluation. Performs one **untimed**
warm-up call (to absorb JIT compilation) and then returns the **minimum**
wall-clock time over `samples` timed runs, in seconds. Intended to be run
single-threaded (`julia -t 1`).

The timed entry point is `DeRham.zeta_function(...; algorithm=:depthfirst,
fastevaluation=true)`, the full zeta function (not `newton_polygon`).

We pass `S = derham_S(n, d)` explicitly — the same canonical S that every
reduction call in `CPUExperiments.jl` uses (via `newton_polygon`). This matters:
`zeta_function`'s built-in default `S = collect(0:n-1)` (projective dimension n-1)
has length `n`, which exceeds `d` and errors out ("Length of S must be <= d") for
cubic surfaces (n_vars=4, d=3 ⟹ default S=[0,1,2,3] but d=3). `derham_S(n, d)`
returns `[0,1,2]` there, and coincides with the default for quartic surfaces and
plane curves, so this is the correct full-zeta S in every case.
"""
function time_zeta_depthfirst(f; samples::Int=3)
    n = nvars(parent(f))          # number of variables (code convention)
    d = total_degree(f)
    S = derham_S(n, d)

    # Untimed JIT warm-up.
    DeRham.zeta_function(f; S=S, algorithm=:depthfirst, fastevaluation=true)

    best = Inf
    for _ in 1:samples
        t = @elapsed DeRham.zeta_function(f; S=S, algorithm=:depthfirst, fastevaluation=true)
        best = min(best, t)
    end
    return best
end
