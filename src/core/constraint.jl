


"Fija que la demanda en un area no se mueva"
function constraint_load_area(pm::_PM.AbstractPowerModel, n::Int; nw::Int=nw_id_default)
    lf = _PM.var(pm, nw, :area_load_factor, n)    
    JuMP.@constraint(pm.model, lf == 1)
end


"Fija que la demanda en una zona no se mueva"
function constraint_load_zone(pm::_PM.AbstractPowerModel, n::Int; nw::Int=nw_id_default)
    lf = _PM.var(pm, nw, :zone_load_factor, n)    
    JuMP.@constraint(pm.model, lf == 1)
end



