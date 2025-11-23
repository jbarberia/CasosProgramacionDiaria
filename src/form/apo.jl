

function constraint_power_balance_with_variable_demand(pm::_PM.AbstractActivePowerModel, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_loads, bus_gs, bus_bs)
    p    = get(_PM.var(pm, n),    :p, Dict()); _PM._check_var_keys(p, bus_arcs, "active power", "branch")
    pg   = get(_PM.var(pm, n),   :pg, Dict()); _PM._check_var_keys(pg, bus_gens, "active power", "generator")
    pd   = get(_PM.var(pm, n),   :pd, Dict()); _PM._check_var_keys(pd, bus_loads, "active power", "load")
    ps   = get(_PM.var(pm, n),   :ps, Dict()); _PM._check_var_keys(ps, bus_storage, "active power", "storage")
    psw  = get(_PM.var(pm, n),  :psw, Dict()); _PM._check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    p_dc = get(_PM.var(pm, n), :p_dc, Dict()); _PM._check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
 
    
    cstr = JuMP.@constraint(pm.model,
        sum(p[a] for a in bus_arcs)
        + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(psw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd[d] for d in bus_loads)        
        - sum(gs for gs in values(bus_gs))*1.0^2
    )

    if _IM.report_duals(pm)
        _PM.sol(pm, n, :bus, i)[:lam_kcl_r] = cstr
        _PM.sol(pm, n, :bus, i)[:lam_kcl_i] = NaN
    end
end


function constraint_fixed_power_factor(pm::_PM.AbstractActivePowerModel, i::Int; nw::Int=nw_id_default)
    # Do nothing, because the model do not have Q.
end
