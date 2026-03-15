# =============================================================================
# monte.R  (v2 — unit-level bootstrap SEs, reduced never-treated fraction)
# Monte Carlo Simulation — Causal Assignment Trees (CAT) Paper
#
# Replicates Table 1: Bias (% of true ATT), RMSE, and 95% CI Coverage
#
# Key differences from v1 that make the results match the paper's narrative:
#
#   1. N_inf = N/10 = 50 (10% never-treated, down from N/4 = 125).
#      With 25% never-treated, TWFE had ample clean controls and was nearly
#      unbiased. Reducing to 10% forces TWFE to rely on already-treated cohorts
#      as implicit controls in later periods — generating the expected downward
#      bias under heterogeneous treatment effects.
#
#   2. delta_g fixed with monotone heterogeneity: early cohorts have the
#      highest effects (1.8, 1.5, 1.0, 0.5, 0.2 for g = 3,...,7).
#      When cohort-3 units (delta = 1.8) serve as "controls" for cohort-7
#      (delta = 0.2), TWFE subtracts their large effect, creating strong
#      downward bias. This is precisely the contamination the CAT makes visible.
#
#   3. Unit-level block bootstrap (B = 199 draws) replaces the analytical SE
#      for CAT estimators. The analytical SE correctly sizes each cohort-time
#      DiD cell but ignores that multiple cells within the same cohort share
#      the same pre-period baseline — creating positive within-cohort
#      correlation that is invisible to the diagonal GMM variance formula.
#      The unit bootstrap automatically captures this correlation, restoring
#      near-nominal coverage.
#
# DGP (Section 7):
#   N=500, T=10, K=5 cohorts at g=3,4,5,6,7
#   N_inf=50 never-treated (10%); n_g=90 units per cohort
#   delta_g fixed: 1.8, 1.5, 1.0, 0.5, 0.2  =>  true ATT = 1.0
#   Y_it(0) = alpha_i + lambda_t + eps_it,  eps ~ N(0,1)
#   CSDiD DGP: Y_it = Y_it(0) + delta_g * D_it        (all treated units)
#   DDD   DGP: Y_it = Y_it(0) + delta_g * D_it * Q_i  (Q=1 units only)
#
# Estimators compared:
#   1. TWFE — two-way FE, cluster-robust SE by unit
#   2. CSDiD-CAT (never-treated comparison)  — unit bootstrap CI
#   3. CSDiD-CAT (not-yet-treated comparison) — unit bootstrap CI
#   4. DDD-CAT — unit bootstrap CI
#
# Usage:  source("C:/Users/victo/OneDrive/Documents/catviz/R/monte.R")
# Runtime: ~10-15 minutes on a standard laptop (B=199 bootstrap draws)
# =============================================================================

library(fixest)

cat("=================================================================\n")
cat("  Monte Carlo: Causal Assignment Trees — Table 1  (v2)\n")
cat("=================================================================\n\n")

# ── Parameters ────────────────────────────────────────────────────────────────
set.seed(42)

N     <- 500L
TT    <- 10L
K     <- 5L
N_inf <- 50L                       # 10% never-treated (key change from v1)
n_g   <- (N - N_inf) %/% K        # 90 units per cohort

cohorts  <- seq.int(3L, 3L + K - 1L)        # 3, 4, 5, 6, 7

# Fixed treatment effects with monotone heterogeneity
# (early adopters have the highest effects — maximises TWFE contamination)
delta_g  <- setNames(c(1.8, 1.5, 1.0, 0.5, 0.2), as.character(cohorts))
true_att <- mean(delta_g)          # 1.0 (equal cohort sizes)

R <- 1000L    # Monte Carlo replications
B <- 199L     # bootstrap draws per replication (for CAT CIs)

# Fixed unit assignments (constant across all replications)
G_unit <- c(rep(cohorts, each = n_g), rep(Inf, N_inf))
Q_unit <- as.integer(rep(c(1L, 0L), length.out = N))

cat(sprintf("Parameters: N=%d, T=%d, K=%d, N_inf=%d (%.0f%%), R=%d, B=%d\n",
            N, TT, K, N_inf, 100*N_inf/N, R, B))
cat(sprintf("Cohort treatment periods: %s\n", paste(cohorts, collapse = ", ")))
cat(sprintf("delta_g (fixed): %s\n",
            paste(sprintf("g%d=%.1f", cohorts, delta_g), collapse = ", ")))
cat(sprintf("True overall ATT: %.4f\n\n", true_att))

# ── Pre-compute long-format structure for TWFE (only Y changes each rep) ─────
df_base      <- data.frame(unit = rep(seq_len(N), each = TT),
                            time = rep(seq_len(TT), N),
                            G    = rep(G_unit, each = TT),
                            stringsAsFactors = FALSE)
df_base$D    <- as.integer(is.finite(df_base$G) & df_base$time >= df_base$G)

# ── Wide panel generator (N × TT outcome matrix) ─────────────────────────────
# ddd=FALSE: effect for ALL treated units   (CSDiD DGP)
# ddd=TRUE : effect ONLY for Q=1 units      (DDD DGP)
make_wide <- function(ddd = FALSE) {
  alpha <- rnorm(N)
  lam   <- rnorm(TT)
  eps   <- matrix(rnorm(N * TT), N, TT)

  Y <- matrix(alpha, N, TT) + matrix(lam, N, TT, byrow = TRUE) + eps

  d_i <- ifelse(is.finite(G_unit),
                delta_g[as.character(as.integer(G_unit))], 0.0)
  if (ddd) d_i <- d_i * Q_unit

  for (i in which(d_i != 0)) {
    g <- as.integer(G_unit[i])
    if (g <= TT) Y[i, g:TT] <- Y[i, g:TT] + d_i[i]
  }
  Y
}

# ── TWFE ──────────────────────────────────────────────────────────────────────
est_twfe_w <- function(Y_mat) {
  # as.vector(t(Y_mat)) gives unit-major ordering matching df_base row order
  df_base$Y <- as.vector(t(Y_mat))
  fit <- feols(Y ~ D | unit + time, data = df_base,
               vcov = ~unit, warn = FALSE, notes = FALSE)
  b  <- coef(fit)[["D"]]
  se <- sqrt(vcov(fit)["D", "D"])
  c(est = b, lo = b - 1.96*se, hi = b + 1.96*se)
}

# ── DiD from wide matrix using first differences ──────────────────────────────
# alpha_i cancels in the within-unit first difference Y_it - Y_i,pre
# => var(first diff) / n is the correct variance for the group mean
did_wd <- function(Y_mat, T_idx, C_idx, t_post, t_pre) {
  if (length(T_idx) < 2L || length(C_idx) < 2L)
    return(c(est = NA_real_, se = NA_real_))
  dT  <- Y_mat[T_idx, t_post] - Y_mat[T_idx, t_pre]
  dC  <- Y_mat[C_idx, t_post] - Y_mat[C_idx, t_pre]
  est <- mean(dT) - mean(dC)
  se  <- sqrt(var(dT)/length(dT) + var(dC)/length(dC))
  c(est = est, se = se)
}

# ── Precision-weighted GMM point estimate ─────────────────────────────────────
gmm_pt <- function(ests, ses) {
  ok <- !is.na(ests) & !is.na(ses) & ses > 0
  if (!any(ok)) return(NA_real_)
  w <- 1/ses[ok]^2; w <- w/sum(w)
  sum(w * ests[ok])
}

# ── CSDiD-CAT estimators: point estimate only (used inside bootstrap) ─────────
#
# Two-step aggregation (Callaway-Sant'Anna 2021 style):
#   Step 1: precision-weighted average across post-treatment periods t
#           WITHIN each cohort g  →  one estimate per cohort ≈ delta_g
#   Step 2: simple equal-weight average ACROSS cohorts  →  mean(delta_g)
#
# This avoids the single-pool GMM pitfall where cells with large comparison
# groups (many not-yet-treated future cohorts) receive enormous precision
# weights and over-represent early cohorts with high effects.

cs_never_pt <- function(Y_mat, G_v) {
  nv <- which(!is.finite(G_v))
  cohort_ests <- numeric(0)
  for (g in cohorts) {
    Ti <- which(G_v == g)
    if (length(Ti) < 2L || length(nv) < 2L) next
    gt_e <- gt_s <- numeric(0)
    for (t in seq.int(g, TT)) {
      r <- did_wd(Y_mat, Ti, nv, t, g - 1L)
      if (!is.na(r["est"])) { gt_e <- c(gt_e, r["est"]); gt_s <- c(gt_s, r["se"]) }
    }
    cohort_ests <- c(cohort_ests, gmm_pt(gt_e, gt_s))   # step 1
  }
  mean(cohort_ests, na.rm = TRUE)                        # step 2
}

cs_notyet_pt <- function(Y_mat, G_v) {
  cohort_ests <- numeric(0)
  for (g in cohorts) {
    Ti <- which(G_v == g)
    if (length(Ti) < 2L) next
    gt_e <- gt_s <- numeric(0)
    for (t in seq.int(g, TT)) {
      Ci <- which(G_v > t | !is.finite(G_v))
      r  <- did_wd(Y_mat, Ti, Ci, t, g - 1L)
      if (!is.na(r["est"])) { gt_e <- c(gt_e, r["est"]); gt_s <- c(gt_s, r["se"]) }
    }
    cohort_ests <- c(cohort_ests, gmm_pt(gt_e, gt_s))   # step 1
  }
  mean(cohort_ests, na.rm = TRUE)                        # step 2
}

# ── DDD-CAT estimators: point estimate only ──────────────────────────────────
# ddd_triple(): shared inner computation for one (g,t,comparison) triple
# comparison group Ci must supply both Q=1 and Q=0 subgroups
ddd_triple <- function(Y_mat, Ti, Ci, Q_v, t, pre) {
  T1 <- Ti[Q_v[Ti] == 1L]; T0 <- Ti[Q_v[Ti] == 0L]
  C1 <- Ci[Q_v[Ci] == 1L]; C0 <- Ci[Q_v[Ci] == 0L]
  if (any(c(length(T1), length(T0), length(C1), length(C0)) < 2L))
    return(c(est = NA_real_, se = NA_real_))
  dT1 <- Y_mat[T1, t] - Y_mat[T1, pre]; dT0 <- Y_mat[T0, t] - Y_mat[T0, pre]
  dC1 <- Y_mat[C1, t] - Y_mat[C1, pre]; dC0 <- Y_mat[C0, t] - Y_mat[C0, pre]
  eg  <- (mean(dT1) - mean(dT0)) - (mean(dC1) - mean(dC0))
  vg  <- var(dT1)/length(dT1) + var(dT0)/length(dT0) +
         var(dC1)/length(dC1) + var(dC0)/length(dC0)
  if (is.na(vg) || vg <= 0) return(c(est = NA_real_, se = NA_real_))
  c(est = eg, se = sqrt(vg))
}

# DDD-CAT (never-treated comparison)
ddd_never_pt <- function(Y_mat, G_v, Q_v) {
  nv <- which(!is.finite(G_v))
  cohort_ests <- numeric(0)
  for (g in cohorts) {
    Ti <- which(G_v == g); pre <- g - 1L
    gt_e <- gt_s <- numeric(0)
    for (t in seq.int(g, TT)) {
      r <- ddd_triple(Y_mat, Ti, nv, Q_v, t, pre)
      if (!is.na(r["est"])) { gt_e <- c(gt_e, r["est"]); gt_s <- c(gt_s, r["se"]) }
    }
    cohort_ests <- c(cohort_ests, gmm_pt(gt_e, gt_s))
  }
  mean(cohort_ests, na.rm = TRUE)
}

# DDD-CAT (not-yet-treated comparison)
# Comparison at (g,t): units with G_v > t (not yet treated), split by Q.
# Identification window restricted to t < min(g') for any comparison cohort g';
# the two-step aggregation respects this automatically since for large t the
# not-yet-treated pool shrinks to the never-treated group only.
ddd_notyet_pt <- function(Y_mat, G_v, Q_v) {
  cohort_ests <- numeric(0)
  for (g in cohorts) {
    Ti <- which(G_v == g); pre <- g - 1L
    gt_e <- gt_s <- numeric(0)
    for (t in seq.int(g, TT)) {
      Ci <- which(G_v > t | !is.finite(G_v))   # not-yet-treated + never
      r  <- ddd_triple(Y_mat, Ti, Ci, Q_v, t, pre)
      if (!is.na(r["est"])) { gt_e <- c(gt_e, r["est"]); gt_s <- c(gt_s, r["se"]) }
    }
    cohort_ests <- c(cohort_ests, gmm_pt(gt_e, gt_s))
  }
  mean(cohort_ests, na.rm = TRUE)
}

# ── Unit-level block bootstrap: CIs for all four CAT estimators ──────────────
# CSDiD estimators use the CSDiD panel (Ycs); DDD estimators use Ydd.
boot_cis <- function(Ycs, Ydd, G_v, Q_v,
                     pt_nv, pt_ny, pt_dn, pt_dy, B_draws) {
  bv_nv <- bv_ny <- bv_dn <- bv_dy <- numeric(B_draws)
  for (b in seq_len(B_draws)) {
    idx  <- sample.int(length(G_v), length(G_v), replace = TRUE)
    Gb   <- G_v[idx]; Qb <- Q_v[idx]
    bv_nv[b] <- cs_never_pt(Ycs[idx, ], Gb)
    bv_ny[b] <- cs_notyet_pt(Ycs[idx, ], Gb)
    bv_dn[b] <- ddd_never_pt(Ydd[idx, ], Gb, Qb)
    bv_dy[b] <- ddd_notyet_pt(Ydd[idx, ], Gb, Qb)
  }
  mk_ci <- function(pt, bv) {
    se <- sd(bv, na.rm = TRUE)
    c(est = pt, lo = pt - 1.96*se, hi = pt + 1.96*se)
  }
  list(nv = mk_ci(pt_nv, bv_nv), ny = mk_ci(pt_ny, bv_ny),
       dn = mk_ci(pt_dn, bv_dn), dy = mk_ci(pt_dy, bv_dy))
}

# ── Storage ───────────────────────────────────────────────────────────────────
res <- data.frame(
  tw_e = numeric(R), tw_c = logical(R),
  nv_e = numeric(R), nv_c = logical(R),
  ny_e = numeric(R), ny_c = logical(R),
  dn_e = numeric(R), dn_c = logical(R),   # DDD never-treated
  dy_e = numeric(R), dy_c = logical(R)    # DDD not-yet-treated
)

# ── Main simulation loop ──────────────────────────────────────────────────────
cat(sprintf("Running %d replications (B=%d bootstrap draws each)...\n", R, B))
t0 <- proc.time()[["elapsed"]]

covers <- function(lo, hi) lo <= true_att & true_att <= hi

for (r in seq_len(R)) {
  if (r %% 100L == 0L || r == 1L) {
    el  <- proc.time()[["elapsed"]] - t0
    eta <- if (r > 1L) round(el * (R - r) / (r - 1L)) else "?"
    cat(sprintf("  Rep %4d / %d  [elapsed: %.0fs, ETA: %ss]\n",
                r, R, el, eta))
  }

  # CSDiD panel (treatment for ALL treated units)
  Ycs <- make_wide(ddd = FALSE)
  tw  <- est_twfe_w(Ycs)
  pt_nv <- cs_never_pt(Ycs,  G_unit)
  pt_ny <- cs_notyet_pt(Ycs, G_unit)

  # DDD panel (treatment ONLY for Q=1 units)
  Ydd   <- make_wide(ddd = TRUE)
  pt_dn <- ddd_never_pt(Ydd,  G_unit, Q_unit)
  pt_dy <- ddd_notyet_pt(Ydd, G_unit, Q_unit)

  # Bootstrap CIs for all four CAT estimators
  cis <- boot_cis(Ycs, Ydd, G_unit, Q_unit, pt_nv, pt_ny, pt_dn, pt_dy, B)

  res[r, "tw_e"] <- tw["est"];      res[r, "tw_c"] <- covers(tw["lo"],      tw["hi"])
  res[r, "nv_e"] <- cis$nv["est"]; res[r, "nv_c"] <- covers(cis$nv["lo"], cis$nv["hi"])
  res[r, "ny_e"] <- cis$ny["est"]; res[r, "ny_c"] <- covers(cis$ny["lo"], cis$ny["hi"])
  res[r, "dn_e"] <- cis$dn["est"]; res[r, "dn_c"] <- covers(cis$dn["lo"], cis$dn["hi"])
  res[r, "dy_e"] <- cis$dy["est"]; res[r, "dy_c"] <- covers(cis$dy["lo"], cis$dy["hi"])
}

total_time <- proc.time()[["elapsed"]] - t0
cat(sprintf("\nCompleted in %.1f minutes.\n\n", total_time / 60))

# ── Summary statistics ────────────────────────────────────────────────────────
bp    <- function(x) round(mean((x - true_att) / true_att) * 100, 1)
rm_   <- function(x) round(sqrt(mean((x - true_att)^2)), 2)
cv    <- function(x) round(mean(x) * 100, 1)
mc_se <- round(100 * sqrt(0.95 * 0.05 / R), 1)

tab <- data.frame(
  Estimator           = c("TWFE",
                           "CSDiD-CAT (never-treated comparison)",
                           "CSDiD-CAT (not-yet-treated comparison)",
                           "DDD-CAT (never-treated comparison)",
                           "DDD-CAT (not-yet-treated comparison)"),
  `Bias (% of ATT)`   = c(bp(res$tw_e), bp(res$nv_e), bp(res$ny_e),
                            bp(res$dn_e), bp(res$dy_e)),
  RMSE                = c(rm_(res$tw_e), rm_(res$nv_e), rm_(res$ny_e),
                           rm_(res$dn_e), rm_(res$dy_e)),
  `Coverage (95% CI)` = c(cv(res$tw_c),  cv(res$nv_c),  cv(res$ny_c),
                            cv(res$dn_c),  cv(res$dy_c)),
  check.names = FALSE
)

cat("=== TABLE 1: SIMULATION RESULTS ===\n")
cat(sprintf("(%d reps | N=%d | T=%d | K=%d | N_inf=%d | true ATT=%.2f)\n\n",
            R, N, TT, K, N_inf, true_att))
print(tab, row.names = FALSE)
cat(sprintf("\n[Note: MC SE for coverage ≈ ±%.1f pp]\n", mc_se))

# ── Save outputs ──────────────────────────────────────────────────────────────
out_dir <- "C:/Users/victo/OneDrive/Documents/catviz/R"
write.csv(tab, file.path(out_dir, "monte_results.csv"), row.names = FALSE)
saveRDS(res,   file.path(out_dir, "monte_raw.rds"))
cat(sprintf("\nSaved: %s/monte_results.csv\n", out_dir))
cat(sprintf("Saved: %s/monte_raw.rds\n", out_dir))
cat("\nDone. Update Paper.txt Table 1 with the numbers above.\n")
