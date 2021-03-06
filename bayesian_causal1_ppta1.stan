data {
  // Number of parameters
  int<lower=1> p;
  // Hyperparameters
  real alpha_mean[p];
  real<lower=0> alpha_sd[p];
  // Number of observations
  int<lower=1> N;
  // Whether to evaluate likelihood
  int<lower=0,upper=1> use_lik;
  // Design matrix
  matrix[N,p] X;
  // Treatment assignment
  int<lower=0,upper=1> A[N];
}

transformed data {

}

parameters {
  // PS model parameters
  vector[p] alpha;
}

transformed parameters {
  // PS linear predictor
  vector[N] ps_lp = X * alpha;
  // PS
  vector[N] ps = inv_logit(ps_lp);
}

model {
  // Priors
  for (j in 1:p) {
    target += normal_lpdf(alpha[j] | alpha_mean[j], alpha_sd[j]);
  }

  // Likelihood: This is the likelihood of the treatment mechanism.
  if (use_lik == 1) {
    for (i in 1:N) {
      target += bernoulli_logit_lpmf(A[i] | ps_lp[i]);
    }
  }
}

generated quantities {
  // For loo
  vector[N] log_lik;
  // For posterior predictive treatment assignment (PPTA)
  int<lower=0,upper=1> A_tilde[N];
  // Selection indicator
  int<lower=0,upper=1> S[N];

  for (i in 1:N) {
    // Observation level log likelihood
    log_lik[i] = bernoulli_logit_lpmf(A[i] | ps_lp[i]);
    // PPTA = Bernoulli realization of PS
    A_tilde[i] = bernoulli_logit_rng(ps_lp[i]);
    // Stochastic inclusion if PPTA differs from treatment assignment
    // S = Bernoulli realization of estimated overlap weights
    S[i] = (A_tilde[i] != A[i]);
  }
}
