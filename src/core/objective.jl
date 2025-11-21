


function objective_measurement_quadratic_loss(pm::_PM.AbstractPowerModel, nw=nw_id_default)
    
    loss = objective_function(pm.model)
    
    # generators
    pg = var(pm, nw, :pg)
    for (i, gen) in ref(pm, nw, :gen)                
        if haskey(gen, "pg_des")            
            pg_des = gen["pg_des"]
            loss += (pg[i] - pg_des)^2
        end        
    end

    JuMP.@objective(pm.model, Min, loss)
end
