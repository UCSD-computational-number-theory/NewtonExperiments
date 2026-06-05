# Thin wrapper around [CHK] = ToricControlledReduction (Costa–Harvey–Kedlaya),
# used as the comparison column of Table 2 (`table:sparse-surfaces`) in
# arxiv:2602.24155.
#
# We do NOT reimplement the toric controlled reduction here. Instead we shell out
# to jjgarzella/MathResearch.jl (vendored as the `comparisons/MathResearch.jl`
# git submodule), whose `zeta_function_tcr(p, f)` writes a TCR input file and runs
# Edgar Costa's C++ `ToricControlledReduction` binary
# (https://github.com/edgarcosta/ToricControlledReduction).
#
# Reproducibility pins (record-only; this file does NOT build or run TCR):
#   * MathResearch.jl : submodule pinned in .gitmodules (HEAD 052580c at vendoring).
#   * ToricControlledReduction : cloned by MathResearch.jl's configure_tcr.bash
#       from https://github.com/edgarcosta/ToricControlledReduction.git
#       (no commit pin upstream; HEAD was 74cda9e8148cd8e9a3928fc15a558c9a70b67cc1
#       at the time of vendoring — pin this in configure_tcr.bash for exact repro).
#
# Building TCR requires NTL/FLINT and is intentionally out of scope here. On any
# box without the built binary, `time_chk` degrades gracefully to `missing` so the
# Table 2 driver still produces our column and emits "–" for [CHK].

using Oscar

const MATHRESEARCH_DIR = normpath(joinpath(@__DIR__, "MathResearch.jl"))
const MATHRESEARCH_SRC = joinpath(MATHRESEARCH_DIR, "src", "ToricControlledReduction.jl")
# Binary produced by `setup_tcr()` -> configure_tcr.bash -> `make examples`.
const TCR_EXE = joinpath(MATHRESEARCH_DIR, "ToricControlledReduction", "build", "examples", "readfile.exe")

# Smallest prime for which we run [CHK]. Toric controlled reduction has a hard
# small-p limit, so Table 2 reports "–" for p = 7 by design (see paper Table 2).
const CHK_MIN_PRIME = 11

"""
    tcr_available() -> Bool

True iff the ToricControlledReduction example binary has been built (i.e. someone
ran `setup_tcr()` inside the MathResearch.jl submodule on this machine). When this
is false, `time_chk` returns `missing` rather than attempting to build or run.
"""
tcr_available() = isfile(TCR_EXE)

# Load MathResearch.jl's `zeta_function_tcr`/`setup_tcr` into this module on first
# use. Done lazily so that merely *including* this wrapper on a box without TCR
# (no UUIDs, no binary) never errors.
function _ensure_tcr_loaded()
    if !isdefined(@__MODULE__, :zeta_function_tcr)
        Base.include(@__MODULE__, MATHRESEARCH_SRC)
    end
    return nothing
end

"""
    time_chk(p, f; samples=3, min_prime=CHK_MIN_PRIME) -> Float64 | Missing

[CHK]/ToricControlledReduction-side timing for Table 2: best-of-`samples`
wall-clock seconds for `zeta_function_tcr(p, f)`, or `missing` when [CHK] does not
apply / cannot run. Never throws — it must not bring down the driver.

Returns `missing` (rendered as "–" in the table) when any of the following hold:
  * `p < min_prime` — skipped by design (TCR small-p limit);
  * the TCR binary is not built on this machine (`tcr_available()` is false);
  * loading or running `zeta_function_tcr` errors out.

`zeta_function_tcr` uses *relative* paths (`./run_tcr.bash`, `data/`), so the call
is made with the working directory set to the MathResearch.jl submodule root.
"""
function time_chk(p, f; samples::Int=3, min_prime::Int=CHK_MIN_PRIME)
    if p < min_prime
        return missing
    end
    if !tcr_available()
        @warn "ToricControlledReduction binary not found; emitting \"–\" for [CHK]. " *
              "Run setup_tcr() inside $(MATHRESEARCH_DIR) once to build it." TCR_EXE
        return missing
    end

    try
        _ensure_tcr_loaded()
        best = Inf
        for _ in 1:samples
            # zeta_function_tcr is defined at runtime via include -> invoke latest.
            t = cd(MATHRESEARCH_DIR) do
                @elapsed Base.invokelatest(zeta_function_tcr, p, f)
            end
            best = min(best, t)
        end
        return best
    catch e
        @warn "ToricControlledReduction timing failed; emitting \"–\" for [CHK]." exception = (e, catch_backtrace())
        return missing
    end
end
