

function run_voltage_correction(file, model_constructor, optimizer; kwargs...)
    return solve_model(
        file,
        model_constructor,
        optimizer,
        build_voltage_correction;
        multinetwork=false,
        ref_extensions=[
            ref_add_area_info!,
            ref_add_zone_info!,
        ], kwargs...)    
end


function build_voltage_correction(pm::AbstractPowerModel)    
    variable_bus_voltage(pm, bounded=true)
    variable_gen_power(pm, bounded=true)        
    variable_branch_power(pm, bounded=false)
    variable_dcline_power(pm, bounded=false)            
    
    variable_branch_transform_magnitude(pm, bounded=false)
    variable_shunt_admitance(pm, bounded=true)
    
    constraint_model_voltage(pm)

    for (i, bus) in ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        constraint_theta_ref(pm, i)        
    end


    # active power setpoint
    for (i, bus) in ref(pm, :bus_gens)
        i in ids(pm,:ref_buses) && continue        
        
        for j in ref(pm, :bus_gens, i)
            constraint_gen_setpoint_active(pm, j)
        end
    end

    # fijo topes de trafos fijos
    for (i, brn) in ref(pm, :branch)        
        get(brn, "control_mode", 0) > 0 && continue
        tm = var(pm, :tm, i)
        fix(tm, brn["tap"]; force=true)        
    end

    # fijo pasos de shunts
    for (i, shunt) in ref(pm, :shunt)
        get(shunt, "control_mode", 0) > 0 && continue
        bs = var(pm, :bs, i)
        fix(bs, shunt["bs"]; force=true)        
    end

    # balance de potencia
    for (i, bus) in ref(pm, :bus)        
        constraint_power_balance_with_variable_shunt(pm, i)
    end

    # flujo de potencia
    for (i, brn) in ref(pm, :branch)
        constraint_ohms_y_oltc_from(pm, i)
        constraint_ohms_y_oltc_to(pm, i)
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
    tm_ctr = objective_transformer_voltage_control(pm)    
    tm_mov = objective_transformer_movement(pm)
    
    sh_ctr = objective_shunt_voltage_control(pm)    
    sh_mov = objective_shunt_movement(pm)
    
    vm_bnd = objective_bus_voltage_band(pm)
    qg_res = objective_gen_reactive_power_reserve(pm)
    
    JuMP.@objective(
        pm.model, 
        Min,
        100 * 0.80 * tm_ctr +
        100 * 2.00 * tm_mov +
        100 * 0.20 * sh_ctr +
        100 * 0.30 * sh_mov +
        100 * 0.50 * vm_bnd +
        100 * 0.20 * qg_res
    )
end
