

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
    variable_load_power(pm, bounded=true)    
    variable_branch_power(pm, bounded=false)
    variable_dcline_power(pm, bounded=false)            

    constraint_model_voltage(pm)

    for (i, bus) in ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        constraint_theta_ref(pm, i)        
    end

    for (i, gen) in ref(pm, :gen)
        if !haskey(gen, "pg_des")
            # TODO ver la mejor forma de ajuste de estos
            # creo que dejarlos libres es buena opción
            # Total el flujo de carga va tendiendo segun las restricciones del flujo
            # constraint_gen_setpoint_active(pm, i)
        end
    end

    # demandas
    constraint_load_agua_del_cajon(pm)    
    
    for (i, load) in ref(pm, :load)
        load["load_bus"] == 5010  && continue # brasil 1
        load["load_bus"] == 5020  && continue # brasil 2
        load["load_bus"] == 43000 && continue # paraguay 1        
        
        # agua del cajon 
        load["load_bus"] == 1200 && continue
        load["load_bus"] == 1202 && continue
        
        constraint_fixed_power_factor(pm, i)        
    end

    # balance de potencia
    for (i, bus) in ref(pm, :bus)        
        constraint_power_balance_with_variable_demand(pm, i)
    end

    # flujo de potencia
    for (i, brn) in ref(pm, :branch)        
        constraint_ohms_y_from(pm, i)
        constraint_ohms_y_to(pm, i)
        constraint_voltage_angle_difference(pm, i)
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
    
    # objetivos
    objective = objective_measurement_quadratic_loss(pm)    
    penalty_1 = objective_transformer_GBA(pm)

    JuMP.@objective(
        pm.model, 
        Min,
        objective 
        + 1e-1 * penalty_1         
    )
end
