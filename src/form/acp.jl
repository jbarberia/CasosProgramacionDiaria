

function constraint_power_balance_with_variable_demand(pm::_PM.AbstractACPModel, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_loads, bus_gs, bus_bs)
    vm   = var(pm, n, :vm, i)
    p    = get(_PM.var(pm, n),    :p, Dict()); _PM._check_var_keys(p, bus_arcs, "active power", "branch")
    pg   = get(_PM.var(pm, n),   :pg, Dict()); _PM._check_var_keys(pg, bus_gens, "active power", "generator")
    pd   = get(_PM.var(pm, n),   :pd, Dict()); _PM._check_var_keys(pd, bus_loads, "active power", "load")
    ps   = get(_PM.var(pm, n),   :ps, Dict()); _PM._check_var_keys(ps, bus_storage, "active power", "storage")
    psw  = get(_PM.var(pm, n),  :psw, Dict()); _PM._check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    p_dc = get(_PM.var(pm, n), :p_dc, Dict()); _PM._check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
    
    q    = get(_PM.var(pm, n),    :q, Dict()); _PM._check_var_keys(q, bus_arcs, "reactive power", "branch")
    qg   = get(_PM.var(pm, n),   :qg, Dict()); _PM._check_var_keys(qg, bus_gens, "reactive power", "generator")
    qd   = get(_PM.var(pm, n),   :qd, Dict()); _PM._check_var_keys(qd, bus_loads, "reactive power", "load")
    qs   = get(_PM.var(pm, n),   :qs, Dict()); _PM._check_var_keys(qs, bus_storage, "reactive power", "storage")
    qsw  = get(_PM.var(pm, n),  :qsw, Dict()); _PM._check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    q_dc = get(_PM.var(pm, n), :q_dc, Dict()); _PM._check_var_keys(q_dc, bus_arcs_dc, "reactive power", "dcline")

    cstr = JuMP.@constraint(pm.model,
        sum(p[a] for a in bus_arcs)
        + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(psw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd[d] for d in bus_loads)
        - sum(gs for gs in values(bus_gs))*vm^2
    )

    csti = JuMP.@constraint(pm.model,
        sum(q[a] for a in bus_arcs)
        + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(qsw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(qg[g] for g in bus_gens)
        - sum(qs[s] for s in bus_storage)
        - sum(qd[d] for d in bus_loads)
        + sum(bs for bs in values(bus_bs))*vm^2
    )

    if _IM.report_duals(pm)
        _PM.sol(pm, n, :bus, i)[:lam_kcl_r] = cstr
        _PM.sol(pm, n, :bus, i)[:lam_kcl_i] = csti
    end
end


function constraint_fixed_power_factor(pm::_PM.AbstractACPModel, i::Int; nw::Int=nw_id_default)
    load = ref(pm, nw, :load, i)
    tan_phi = load["pd"] / load["qd"]
    pd = var(pm, nw, :pd, i)
    qd = var(pm, nw, :qd, i)
    if isinf(tan_phi) || isnan(tan_phi)
        @constraint(pm.model, qd == 0)
    else
        @constraint(pm.model, pd == qd * tan_phi)
    end
end

