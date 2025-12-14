


function objective_measurement_quadratic_loss(pm::_PM.AbstractPowerModel, nw=nw_id_default)
    
    old_objective = objective_function(pm.model)
    loss = 0
    measures = 0
    
    # generators
    pg = var(pm, nw, :pg)
    for (i, gen) in ref(pm, nw, :gen)                
        if haskey(gen, "pg_des")            
            pg_des = gen["pg_des"]
            loss += (pg[i] - pg_des)^2
            measures += 1
        end        
    end

    # interchanges
    p = var(pm, nw, :p)
    for (i, flow) in ref(pm, nw, :flows)
        indices = filter(idx -> idx in p.axes[1], flow["branches"])        
        p_meas = sum(p[idx] for idx in indices)
        p_des = flow["p_des"]
        loss += (p_meas - p_des)^2
        measures += 1
    end
    
    JuMP.@objective(pm.model, Min, old_objective + loss / measures)
end


function objective_transformer_voltage_control(pm::_PM.AbstractPowerModel, nw=nw_id_default)    
    old_objective = objective_function(pm.model)
    loss = 0
    n = 0
    for (i, brn) in ref(pm, nw, :branch)
        if haskey(brn, "control_bus")    
            control_bus = brn["control_bus"]
            control_bus == 0 && continue

            rho = 0.01
            alpha = 200
            vm = var(pm, nw, :vm, control_bus)
            vmax = brn["vm_max"]
            vmin = brn["vm_min"]

            loss += rho/alpha * log(1 + exp(alpha * (vmin - vm)))
            loss += rho/alpha * log(1 + exp(alpha * (vm - vmax)))
            n += 1
        end
    end
   
    JuMP.@objective(pm.model, Min, old_objective + loss / n)
end


function objective_transformer_GBA(pm::_PM.AbstractPowerModel, nw=nw_id_default)
    old_objective = objective_function(pm.model)
    loss = 0
    n = 0
    
    source2idx = Dict(brn["source_id"] => (i, brn["f_bus"], brn["t_bus"]) for (i, brn) in ref(pm, :branch))   
    
    xfmr_gba = [
        ["T3", 3138, 3386, 3519, "1 ", 1],
        ["T3", 3138, 3386, 3520, "2 ", 1],
        ["T3", 3130, 3372, 3542, "8 ", 1],
        ["T3", 3130, 3372, 3515, "7 ", 1],
        ["T3", 3136, 3743, 3518, "2 ", 1],
        ["T3", 3136, 3744, 3532, "3 ", 1],
        ["T3", 3146, 3466, 3534, "1 ", 1],
        ["T3", 3146, 3466, 3535, "2 ", 1],
        ["T3", 3150, 3262, 3530, "1 ", 1],
        ["T3", 3132, 3371, 3516, "6 ", 1],
        ["T3", 3149, 3290, 3581, "1 ", 1],
        ["T3", 3134, 3746, 3517, "1 ", 1],
        ["T3", 3144, 3410, 3526, "1 ", 1],
        ["T3", 3145, 3410, 3531, "2 ", 1],
    ]

    for xfmr in xfmr_gba
        index = source2idx[xfmr]
        p = var(pm, nw, :p, index)
        p_max =  2.8
        p_min = -2.8       
        rho = 0.01
        alpha = 200
        loss += rho/alpha * log(1 + exp(alpha * (p_min - p)))
        loss += rho/alpha * log(1 + exp(alpha * (p - p_max)))
        n += 1
    end
    

    JuMP.@objective(pm.model, Min, old_objective + loss / n)
end
