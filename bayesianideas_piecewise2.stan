data {
    // Hypeparameters for lambda[1]
    real<lower=0> w1;
    real<lower=0> lambda1_star;
    // Hyperparameter for lambda[k]
    real<lower=0> w;
    real<lower=0> lambda_star;
    // Hyperparameter for beta
    real beta_mean;
    real<lower=0> beta_sd;
    // Number of pieces
    int<lower=0> K;
    // Cutopoints on time
    //  cutpoints[1] = 0
    //  max(event time) < cutpoints[K+1] < Inf
    //  K+1 elements
    real cutpoints[K+1];
    //
    int<lower=0> N;
    int<lower=0,upper=1> cens[N];
    real y[N];
    int<lower=0,upper=1> x[N];
    //
    // grids for evaluating posterior predictions
    int<lower=0> grid_size;
    real grid[grid_size];
    // Whether to evalulate the likelihood in model {}
    // https://twitter.com/JamesBland_Econ/status/1138402318645432320
    int<lower=0,upper=1> eval_likelihood;
}

transformed data {
}

parameters {
    // Baseline hazards
    real<lower=0> lambda[K];
    // Effect of group
    real beta;
}

transformed parameters {
}

model {
    // Prior on beta
    target += normal_lpdf(beta | beta_mean, beta_sd);

    // Loop over pieces of time (intervals).
    for (k in 1:K) {
        // k = 1,2,...,K
        // cutpoints[1] = 0
        // cutpoints[K+1] > max event time
        real length = cutpoints[k+1] - cutpoints[k];

        // Prior on lambda
        // BIDA 13.2.5 Priors for lambda
        if (k == 1) {
            // The first interval requires special handling when it is empty by design.
            target += gamma_lpdf(lambda[1] | lambda1_star * length * w1, length * w1);
        } else {
            // Mean lambda_star
            target += gamma_lpdf(lambda[k] | lambda_star  * length * w,  length * w);
        }

        // Likelihood contribution
        // BIDA 13.2.3 Likelihood for piecewise hazard PH model
        if (eval_likelihood == 1) {
            // Only evaluate likelihood if asked.
            for (i in 1:N) {
                // Linear predictor
                real lp = beta * x[i];
                // Everyone will contribute to the survival part.
                if (y[i] >= cutpoints[k+1]) {
                    // If surviving beyond the end of the interval,
                    // contribute survival throughout the interval.
                    target += -exp(lp) * (lambda[k] * length);
                    //
                } else if (cutpoints[k] <= y[i] && y[i] < cutpoints[k+1]) {
                    // If ending follow up during the interval,
                    // contribute survival until the end of follow up.
                    target += -exp(lp) * (lambda[k] * (y[i] - cutpoints[k]));
                    //
                    // Event individuals also contribute to the hazard part.
                    if (cens[i] == 1) {
                        target += lp + log(lambda[k]);
                    }
                } else {
                    // If having ended follow up before this interval,
                    // no contribution in this interval.
                }
            }
        }
    }
}

generated quantities {
    // Hazard function evaluated at grid points
    real<lower=0> h0_grid[grid_size];
    // Cumulative hazard function at grid points
    real<lower=0> H0_grid[grid_size];
    // Survival function at grid points
    real<lower=0> S0_grid[grid_size];
    real<lower=0> S1_grid[grid_size];
    // Time zero cumulative hazard should be zero.
    H0_grid[1] = 0;

    // Loop over grid points
    for (g in 1:grid_size) {
        // Loop over cutpoints
        for (k in 1:K) {
            // At each k, hazard is constant at lambda[k]
            if (cutpoints[k] <= grid[g] && grid[g] < cutpoints[k+1]) {
                h0_grid[g] = lambda[k];
                break;
            }
        }
        // Set grid points beyond the last time cutoff to zeros.
        if (grid[g] >= cutpoints[K+1]) {
            h0_grid[g] = 0;
        }
        // Cumulative hazard
        if (g > 1) {
            // This double loop is very inefficient.
            // Index starts at 2!
            for (gg in 2:g) {
                // Width between current grid points
                real width = grid[gg] - grid[gg-1];
                // Width x hazard value at first grid point.
                // This is approximation and is incorrect for grid points
                // between which the hazard changes.
                // Previous cumulative + current contribution.
                H0_grid[g] = H0_grid[g-1] + (width * h0_grid[gg-1]);
            }
        }
        // Survival
        S0_grid[g] = exp(-H0_grid[g]);
        S1_grid[g] = S0_grid[g]^exp(beta);
    }
}
