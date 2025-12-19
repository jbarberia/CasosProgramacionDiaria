


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


"""
Esta restriccion emula el poder pasar los generadores que aportan a 500 kV a 132 kV
"""
function constraint_load_agua_del_cajon(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default)
    loads = Dict(load["source_id"] => i for (i, load) in ref(pm, :load))
    pd_500 = var(pm, nw, :pd, loads[["LO", 1200, "99"]])
    pd_132 = var(pm, nw, :pd, loads[["LO", 1202, "99"]])
    
    source_ids = [
        ["ME", 1602, "2 "],
        ["ME", 1606, "1 "],
        ["ME", 1601, "1 "],
        ["ME", 1604, "4 "],
        ["ME", 1600, "6 "],
    ]
    generators = Dict(gen["source_id"] => gen for (i, gen) in ref(pm, :gen))

    p_instalada = 0
    p_despachada = pd_500 + pd_132
    for source_id in source_ids
        gen = get(generators, source_id, nothing)
        isnothing(gen) && continue
        p_instalada += gen["pmax"]
        p_despachada += var(pm, nw, :pg, gen["index"])
    end

    @constraint(pm.model, pd_500 >= 0.0)
    @constraint(pm.model, pd_132 <= 0.0)
    @constraint(pm.model, pd_132 + pd_500 == 0.0)
    @constraint(pm.model, p_despachada >= 0.0)
    @constraint(pm.model, p_despachada <= p_instalada)
end

