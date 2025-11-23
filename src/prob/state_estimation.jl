

function run_state_estimation(file, model_constructor, optimizer; kwargs...)
    return solve_model(
        file,
        model_constructor,
        optimizer,
        build_state_estimation;
        multinetwork=false,
        ref_extensions=[
            ref_add_area_info!,
            ref_add_zone_info!,
        ], kwargs...)    
end


function build_state_estimation(pm::AbstractPowerModel)    
    variable_bus_voltage(pm, bounded=true)
    variable_gen_power(pm, bounded=true)    
    variable_load_power(pm, bounded=false)
    variable_branch_power(pm, bounded=false)
    variable_dcline_power(pm, bounded=false)            

    constraint_model_voltage(pm)

    for (i, bus) in ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        constraint_theta_ref(pm, i)        
    end

    for (i, gen) in ref(pm, :gen)
        if !haskey(gen, "pg_des")
            # constraint_gen_setpoint_active(pm, i)
        end
    end

    # balance de potencia
    for (i, bus) in ref(pm, :bus)        
        constraint_power_balance_with_variable_demand(pm, i)
    end

    # flujo de potencia
    for i in ids(pm, :branch)
        constraint_ohms_yt_from(pm, i)
        constraint_ohms_yt_to(pm, i)
        constraint_voltage_angle_difference(pm, i)
    end

    # factor de potencia fijo en demanda
    for i in ids(pm, :load)
        constraint_fixed_power_factor(pm, i)
    end


    # flujo de lineas HVDC
    for (i, dcline) in ref(pm, :dcline)
        constraint_dcline_setpoint_active(pm, i)
        
        f_bus = ref(pm, :bus)[dcline["f_bus"]]
        if f_bus["bus_type"] == 1
            constraint_voltage_magnitude_setpoint(pm, f_bus["index"])
        end

        t_bus = ref(pm, :bus)[dcline["t_bus"]]
        if t_bus["bus_type"] == 1
            constraint_voltage_magnitude_setpoint(pm, t_bus["index"])
        end
    end
    
    objective_measurement_quadratic_loss(pm)
end
