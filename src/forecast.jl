mutable struct Forecast{Fl}
    expected_value::Vector{Vector{Fl}}
    covariance::Vector{Matrix{Fl}}
end

function forecast_expected_value(forec::Forecast)
    return permutedims(cat(forec.expected_value...; dims = 2))
end

"""
    forecast(model::SSM, steps_ahead::Int; kwargs...) where SSM
    forecast(model::SSM, exogenous::Matrix{Fl}; kwargs...) where {SSM, Fl}

Forecast the mean and covariance for future observations from a StateSpaceModel (SSM).
"""
function forecast end

function forecast(model::StateSpaceModel, steps_ahead::Int;
                  filter::KalmanFilter = default_filter(model))
    if has_exogenous(model)
        error("The model has exogenous variables, you should use the" *
              "forecast(model::SSM, exogenous::Matrix{Fl}; kwargs...) method")
    end
    # Query the type of model elements
    Fl = typeof_model_elements(model)
    # Observations to forecast
    forecasting_y = [model.system.y; fill(NaN, steps_ahead)]
    # Copy hyperparameters
    model_hyperparameters = deepcopy(model.hyperparameters)
    # Instantiate a new model
    forecasting_model = reinstantiate(model, forecasting_y)
    # Associate with the model hyperparameters
    forecasting_model.hyperparameters = model_hyperparameters
    # Perform the kalman filter
    fo = kalman_filter(forecasting_model)
    # fill forecast matrices
    expected_value = Vector{Vector{Fl}}(undef, steps_ahead)
    covariance = Vector{Matrix{Fl}}(undef, steps_ahead)
    for i in 1:steps_ahead
        expected_value[i] = [dot(model.system.Z, fo.a[end - steps_ahead + i]) + model.system.d]
        covariance[i] = fo.F[end - steps_ahead + i]
    end
    return Forecast{Fl}(expected_value, covariance)
end

function forecast(model::StateSpaceModel, new_exogenous::Matrix{Fl};
                  filter::KalmanFilter = default_filter(model)) where {Fl}
    if !has_exogenous(model)
        error("The model does not support exogenous variables, you should use the" *
              "forecast(model::SSM, steps_ahead::Int; kwargs...) where SSM")
    end
    steps_ahead = size(new_exogenous, 1)
    forecasting_y = [model.system.y; fill(NaN, steps_ahead)]
    forecasting_X = [model.exogenous; new_exogenous]
    # Copy hyperparameters
    model_hyperparameters = deepcopy(model.hyperparameters)
    # Instantiate a new model
    forecasting_model = reinstantiate(model, forecasting_y, forecasting_X)
    # Associate with the model hyperparameters
    forecasting_model.hyperparameters = model_hyperparameters
    # Perform the kalman filter
    fo = kalman_filter(forecasting_model)
    # fill forecast matrices
    expected_value = Vector{Vector{Fl}}(undef, steps_ahead)
    covariance = Vector{Matrix{Fl}}(undef, steps_ahead)
    for i in 1:steps_ahead
        expected_value[i] = [dot(model.system.Z[end - steps_ahead + i], fo.a[end - steps_ahead + i]) + 
                                 model.system.d[end - steps_ahead + i]]
        covariance[i] = fo.F[end - steps_ahead + i]
    end
    return Forecast{Fl}(expected_value, covariance)
end

"""
    simulate_scenarios(
        model::StateSpaceModel, steps_ahead::Int, n_scenarios::Int;
        filter::KalmanFilter=default_filter(model)
    ) -> Array{<:AbstractFloat, 3}

Samples `n_scenarios` future scenarios via Monte Carlo simulation for `steps_ahead`
using the desired `filter`.
"""
function simulate_scenarios(
    model::StateSpaceModel, steps_ahead::Int, n_scenarios::Int;
    filter::KalmanFilter=default_filter(model)
)
    # Query the type of model elements
    Fl = typeof_model_elements(model)
    fo = kalman_filter(model)
    last_state = fo.a[end]
    num_series = size(model.system.y, 2)

    scenarios = Array{Fl, 3}(undef, steps_ahead, num_series, n_scenarios)
    for s in 1:n_scenarios
        scenarios[:, :, s] = simulate(model.system, last_state, steps_ahead)
    end
    return scenarios
end
