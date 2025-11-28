


function objective_measurement_quadratic_loss(pm::_PM.AbstractPowerModel, nw=nw_id_default)
    
    loss = objective_function(pm.model)
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
    
    JuMP.@objective(pm.model, Min, loss / measures)
end
