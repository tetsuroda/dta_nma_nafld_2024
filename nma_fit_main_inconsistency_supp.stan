functions{
  
  real scaled_binomial_lpmf(int x, int n, real p, real s){
    return(
      lgamma(n*s + 1) - lgamma(x*s + 1) - lgamma(n*s - x*s + 1) +
      x*s * log(p) + (n*s - x*s) * log(1 - p));
  }
  
}

data {
  int N; // number of observations
  int J; // sensitivity and specificity = 2
  int S; // number of different studies
  int T; // number of different test types
  int Test[N]; // test types
  int Study[N]; // study number
  int Threshold[N]; // threshold
  int TP[N];
  int FP[N];
  int FN[N];
  int TN[N];
  int prior_type;
  int W[N];
}

transformed data {
  int Y_pos[N];
  int Y_neg[N];
  for(n in 1:N){
    Y_pos[n] = TP[n] + FN[n]; // num positive
    Y_neg[n] = TN[n] + FP[n]; // num negative
  }
}

parameters{
  vector[T] muSe;
  vector[T] muSp;
  vector[2] omegaSe;
  vector[2] omegaSp;
  real<lower=0> sigSe;
  real<lower=0> sigSp;
  real<lower=0> tau0_se;
  real<lower=0> tau0_sp;
  real<lower=0> tau1_se;
  real<lower=0> tau1_sp;
  vector[S] z_0;
  matrix[T,S] z_1;
  vector[2] z[N];
  cholesky_factor_corr[2] L_Omega;
}

transformed parameters{
  vector[2] theta[N];
  vector[2] P[N];
  vector[2] Mu[N];
  vector<lower=0>[2] Sig;
  vector[S] gamma0_se;
  vector[S] gamma0_sp;
  vector[S] gamma1_se[T];
  vector[S] gamma1_sp[T];
  matrix[2,2] L;
  
  Sig[1] = sigSe;
  Sig[2] = sigSp;
  
  L = diag_pre_multiply(Sig, L_Omega);
  
  gamma0_se = tau0_se*z_0;
  gamma0_sp = tau0_sp*z_0;
  
  for (t in 1:T){
    for (s in 1:S){
      gamma1_se[t,s] = tau1_se*z_1[t,s];
      gamma1_sp[t,s] = tau1_sp*z_1[t,s];
    }
  }
  
  
  for (i in 1:N){
    if (W[i] == 0 || W[i] == 1 || W[i] == 4) {
      Mu[i,1] = muSe[Test[i]] + gamma0_se[Study[i]] + gamma1_se[Test[i], Study[i]];
      Mu[i,2] = muSp[Test[i]] + gamma0_sp[Study[i]] + gamma1_sp[Test[i], Study[i]];
    } else {
      Mu[i,1] = muSe[Test[i]] + omegaSe[W[i] - 1] + gamma0_se[Study[i]] + gamma1_se[Test[i], Study[i]];
      Mu[i,2] = muSp[Test[i]] + omegaSp[W[i] - 1] + gamma0_sp[Study[i]] + gamma1_sp[Test[i], Study[i]];
    }
  }
  
  for (n in 1:N){
    theta[n] = Mu[n] + L*z[n];
  }
  
  P = inv_logit(theta);
  
}

model {
  for (i in 1:N){
    TP[i] ~ scaled_binomial(Y_pos[i], P[i,1], 1e-03);
    TN[i] ~ scaled_binomial(Y_neg[i], P[i,2], 1e-03);
  }
  
  // priors
  for (i in 1:N){
    z[i] ~ normal(0,1);
  }
  if (prior_type == 1) {
    
    muSe ~ normal(0, 2);
    muSp ~ normal(0, 2);
    omegaSe[1] ~ normal(0, 2);
    omegaSp[1] ~ normal(0, 2);
    omegaSe[2] ~ normal(0, 2);
    omegaSp[2] ~ normal(0, 2);
    tau0_se ~ uniform(0, 5);
    tau0_sp ~ uniform(0, 5);
    tau1_se ~ uniform(0, 5);
    tau1_sp ~ uniform(0, 5);
    sigSe ~ uniform(0, 5);
    L_Omega ~ lkj_corr_cholesky(4);
    
  } else if (prior_type == 2) {
    
    muSe ~ normal(0, 5);
    muSp ~ normal(0, 5);
    omegaSe[1] ~ normal(0, 5);
    omegaSp[1] ~ normal(0, 5);
    omegaSe[2] ~ normal(0, 5);
    omegaSp[2] ~ normal(0, 5);
    tau0_se ~ uniform(0, 10);
    tau0_sp ~ uniform(0, 10);
    tau1_se ~ uniform(0, 10);
    tau1_sp ~ uniform(0, 10);
    sigSe ~ uniform(0, 10);
    L_Omega ~ lkj_corr_cholesky(6);
  } 
  
  
  z_0 ~ normal(0,1);
  to_vector(z_1) ~ normal(0,1);
}

generated quantities {
  vector[T] sepool = inv_logit(muSe);
  vector[T] sppool = inv_logit(muSp);
  matrix[T,2] mu;
  vector[N] log_lik;
  corr_matrix[2] Corr;
  vector[2] theta_pred[T];
  vector<lower=0, upper=1>[2] sesp_pred[T];
  matrix[T, T] se_diff;
  matrix[T, T] sp_diff;
  matrix[T, T] sepred_diff;
  matrix[T, T] sppred_diff;
  real d_Se_TE_pSWE_direct;
  real d_Se_TE_pSWE_indirect;
  real d_Sp_TE_pSWE_direct;
  real d_Sp_TE_pSWE_indirect;
  
  real d_Se_2dSWE_pSWE_direct;
  real d_Se_2dSWE_pSWE_indirect;
  real d_Sp_2dSWE_pSWE_direct;
  real d_Sp_2dSWE_pSWE_indirect;
  
  real d_Se_MRE_pSWE_indirect;
  real d_Sp_MRE_pSWE_indirect;
  
  d_Se_TE_pSWE_direct = muSe[1] - muSe[3];
  d_Se_TE_pSWE_indirect = muSe[1] + omegaSe[1] - muSe[3];
  d_Sp_TE_pSWE_direct = muSp[1] - muSp[3];
  d_Sp_TE_pSWE_indirect = muSp[1] + omegaSp[1] - muSp[3];
  
  d_Se_2dSWE_pSWE_direct = muSe[4] - muSe[3];
  d_Se_2dSWE_pSWE_indirect = muSe[4] + omegaSe[2] - muSe[3];
  d_Sp_2dSWE_pSWE_direct = muSp[4] - muSp[3];
  d_Sp_2dSWE_pSWE_indirect = muSp[4] + omegaSp[2] - muSp[3];
  
  d_Se_MRE_pSWE_indirect = muSe[2] - muSe[3];
  d_Sp_MRE_pSWE_indirect = muSp[2] - muSp[3];
  
  mu[1:T,1] = muSe;
  mu[1:T,2] = muSp;
  
  // predictive distribution
  for (k in 1:T) {
    mu[k,1] = normal_rng(muSe[k], tau0_se + tau1_se);
    mu[k,2] = normal_rng(muSp[k], tau0_sp + tau1_sp);
    theta_pred[k] = multi_normal_cholesky_rng(mu[k], diag_pre_multiply(Sig, L_Omega));
    sesp_pred[k] = inv_logit(theta_pred[k]);
  }
  
  // For calculating DIC
  for (n in 1:N) {
    log_lik[n] = scaled_binomial_lpmf(TP[n] | Y_pos[n], P[n,1], 1e-3) +
    scaled_binomial_lpmf(TN[n] | Y_neg[n], P[n,2], 1e-3);
  }
  
  
  for (k in 1:T) {
    for (j in 1:T) {
      // sensitivity league table
      se_diff[k,j] = sepool[k] - sepool[j]; 
      
      // specificity league table
      sp_diff[k,j] = sppool[k] - sppool[j]; 
      
      // prediction league table
      sepred_diff[k,j] = sesp_pred[k,1] - sesp_pred[j,1]; 
      sppred_diff[k,j] = sesp_pred[k,2] - sesp_pred[j,2];
    }
  }
  
  // To recover the correlation matrix
  Corr = multiply_lower_tri_self_transpose(L_Omega);
  
}
