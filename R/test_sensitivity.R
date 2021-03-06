# helpers for the core sensitivity analysis function

create_konfound_class <- function(x) {
    structure(x, class = "konfound")
}

#' Concise summary of konfound output
#' @details Prints a concise summary of konfound output with multiple types of data specified in the to_return argument
#' @param object A `konfound` object
#' @param ... Additional arguments
#' @export

summary.konfound <- function(object, ...){
    cat("Created", length(object), "forms of output. To access type: \n")
    cat("\n")
    
    for (name in names(object)) {
        cat(rlang::expr_text(substitute(object)), "$", name, "\n", sep = "")
    }
}

# Main function to test sensitivity to be wrapped with pkonfound(), konfound(), and mkonfound()

test_sensitivity <- function(est_eff,
                             std_err,
                             n_obs,
                             n_covariates,
                             alpha,
                             tails,
                             nu,
                             to_return,
                             model_object,
                             tested_variable) {
    
    # calculating statistics used in every case
    if (est_eff < 0) {
        critical_t <- stats::qt(1 - (alpha / tails), n_obs - n_covariates - 1) * -1 }
    else {critical_t <- stats::qt(1 - (alpha / tails), n_obs - n_covariates - 1) }
    
    beta_threshold <- critical_t * std_err
    # dealing with cases where hypotheses other than whether est_eff differs from 0
    if (nu != 0) {
        est_eff <- abs(est_eff - nu) } else {
            est_eff <- est_eff - 0 } # this is just to make what this is doing evident
    
    # for replacement of cases approach
    
    # calculating percentage of effect and number of observations to sustain or invalidate inference
    if (abs(est_eff) > abs(beta_threshold)) {
        bias <- 100 * (1 - (beta_threshold / est_eff))
        recase <- round(n_obs * (bias / 100)) }
    else if (abs(est_eff) < abs(beta_threshold)) {
        sustain <- 100 * (1 - (est_eff / beta_threshold))
        recase <- round(n_obs * (sustain / 100)) }
    else if (est_eff == beta_threshold) {
        stop("The coefficient is exactly equal to the threshold.") }
    
    # for correlation-based approach
    
    # transforming t into r
    obs_r <- (est_eff / std_err) / sqrt(((n_obs - n_covariates - 3) + ((est_eff / std_err) ^ 2)))
    # finding critical r
    critical_r <- critical_t / sqrt((critical_t ^ 2) + (n_obs - n_covariates - 3))
    # calculating threshold
    if ((abs(obs_r) > abs(critical_r)) & ((obs_r * critical_r) > 0)) {
        mp <- -1
    } else {
        mp <- 1
    }
    # calculating impact of the confounding variable
    itcv <- (obs_r - critical_r) / (1 + mp * abs(critical_r))
    # finding correlation of confound to invalidate / sustain inference
    r_con <- round(sqrt(abs(itcv)), 3)
    
    # if (component_correlations == FALSE){
    #     rsq <- # has to come from some kind of model object
    #         varY <- # has to come from some kind of model object
    #         varX <- # has to come from some kind of model object
    #         sdX <- # has to come from some kind of model object
    #         
    #         rsqYZ = (((obs_r ^ 2) - Rsq) / ((obs_r ^ 2) - 1))
    #     
    #     rsqXZ = max(0, 1 - ((VarY * (1 - RSQ))) / (VarX * (n_obs - n_covariates - 2) * (sdx * 2)))
    #     
    #     r_ycv = r_con * sqrt(1 - rsqYZ)
    #     r_xcv = r_con * sqrt(1 - rsqXZ)  
    #     # before conditioning on observed covariates
    # }
    
    # output dispatch

    if (length(to_return) > 1) {
        to_return <-to_return[!(to_return == "print")]

        konfound_output <- purrr::map(to_return,
                                      ~ test_sensitivity(
                                          est_eff = est_eff,
                                          std_err = std_err,
                                          n_obs = n_obs, 
                                          n_covariates = n_covariates,
                                          alpha = alpha, 
                                          tails = tails,
                                          nu = nu,
                                          to_return = .))
        konfound_output <- create_konfound_class(konfound_output)
        names(konfound_output) <- to_return
        output_print(est_eff, beta_threshold, bias, sustain, nu, recase, obs_r, critical_r, r_con, itcv, alpha)
        
        cat("\n")
        message(paste("Print output created by default. Created", length(konfound_output), "other forms of output. Use list indexing or run summary() on the output to see how to access."))
        
        return(konfound_output) 

    } 
    
    else if (to_return == "raw_output") return(output_df(est_eff, beta_threshold, est_eff, bias, sustain, recase, obs_r, critical_r, r_con, itcv))
    else if (to_return == "thresh_plot") return(plot_threshold(beta_threshold = beta_threshold, est_eff = est_eff))
    else if (to_return == "corr_plot") return(plot_correlation(r_con = r_con, obs_r = obs_r, critical_r = critical_r))
    else if (to_return == "print") return(output_print(est_eff, beta_threshold, bias, sustain, nu, recase, obs_r, critical_r, r_con, itcv, alpha))
    else if (to_return == "table") return(output_table(model_object, tested_variable))
    else {
        stop("to_return must be set to 'raw_output', 'print', 'table', 'thresh_plot', or 'corr_plot' or some combination thereof")
    }
}
