# This file define interfaces with the filters defined in the filters folder
abstract type KalmanFilter end

const HALF_LOG_2_PI = 0.5 * log(2 * pi)

# Default loglikelihood function for optimization
function optim_loglike(model::StateSpaceModel, 
                       filter::KalmanFilter, 
                       unconstrained_hyperparameters::Vector{Fl}) where Fl
    reset_filter!(filter)
    update_model_hyperparameters!(model, unconstrained_hyperparameters)
    update_filter_hyperparameters!(filter, model)
    return optim_kalman_filter(model.system, filter)
end

function update_model_hyperparameters!(model::StateSpaceModel, 
                                       unconstrained_hyperparameters::Vector{Fl}) where Fl
    register_unconstrained_values!(model, unconstrained_hyperparameters)
    constraint_hyperparameters!(model)
    update!(model)
    return nothing
end
# @time StateSpaceModels2.
function update_filter_hyperparameters!(filter::KalmanFilter, model::StateSpaceModel)
    update!(filter, model)
    return nothing
end
function update!(::KalmanFilter, ::StateSpaceModel)
    return nothing
end

function loglike(model::StateSpaceModel;
                 filter::KalmanFilter = default_filter(model))
    return optim_loglike(model, filter, get_free_unconstrained_values(model))
end

"""
"""
mutable struct FilterOutput{Fl <: Real}
    v::Vector{Vector{Fl}}
    F::Vector{Matrix{Fl}}
    a::Vector{Vector{Fl}}
    att::Vector{Vector{Fl}}
    P::Vector{Matrix{Fl}}
    Ptt::Vector{Matrix{Fl}}
    Pinf::Vector{Matrix{Fl}}

    function FilterOutput(model::StateSpaceModel)
        Fl = typeof_model_elements(model)
        n = size(model.system.y, 1)

        v = Vector{Vector{Fl}}(undef, n)
        F = Vector{Matrix{Fl}}(undef, n)
        a = Vector{Vector{Fl}}(undef, n + 1)
        att = Vector{Vector{Fl}}(undef, n)
        P = Vector{Matrix{Fl}}(undef, n + 1)
        Ptt = Vector{Matrix{Fl}}(undef, n)
        Pinf = Vector{Matrix{Fl}}(undef, n)
        return new{Fl}(v, F, a, att, P, Ptt, Pinf)
    end
end

"""
"""
function kalman_filter(model::StateSpaceModel;
                       filter::KalmanFilter = default_filter(model)) where Fl
    filter_output = FilterOutput(model)
    reset_filter!(filter)
    free_unconstrained_values = get_free_unconstrained_values(model)
    update_model_hyperparameters!(model, free_unconstrained_values)
    update_filter_hyperparameters!(filter, model)
    return kalman_filter!(filter_output, model.system, filter)
end

"""
"""
mutable struct SmootherOutput{Fl <: Real}
    alpha::Vector{Vector{Fl}}
    V::Vector{Matrix{Fl}}

    function SmootherOutput(model::StateSpaceModel)
        Fl = typeof_model_elements(model)
        n = size(model.system.y, 1)

        alpha = Vector{Vector{Fl}}(undef, n)
        V = Vector{Matrix{Fl}}(undef, n)
        return new{Fl}(alpha, V)
    end
end

"""
"""
function kalman_smoother(model::StateSpaceModel;
                         filter::KalmanFilter = default_filter(model)) where Fl
    filter_output = FilterOutput(model)
    kalman_filter!(filter_output, model.system, filter)
    smoother_output = SmootherOutput(model)
    return kalman_smoother!(smoother_output, model.system, filter_output)
end