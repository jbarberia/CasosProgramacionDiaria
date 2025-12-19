

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


function constraint_power_balance_with_variable_shunt(pm, n, i, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_loads, bus_shunts)
    vm   = var(pm, n, :vm, i)
    p    = get(_PM.var(pm, n),    :p, Dict()); _PM._check_var_keys(p, bus_arcs, "active power", "branch")
    pg   = get(_PM.var(pm, n),   :pg, Dict()); _PM._check_var_keys(pg, bus_gens, "active power", "generator")    
    ps   = get(_PM.var(pm, n),   :ps, Dict()); _PM._check_var_keys(ps, bus_storage, "active power", "storage")
    psw  = get(_PM.var(pm, n),  :psw, Dict()); _PM._check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    p_dc = get(_PM.var(pm, n), :p_dc, Dict()); _PM._check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
    
    q    = get(_PM.var(pm, n),    :q, Dict()); _PM._check_var_keys(q, bus_arcs, "reactive power", "branch")
    qg   = get(_PM.var(pm, n),   :qg, Dict()); _PM._check_var_keys(qg, bus_gens, "reactive power", "generator")    
    qs   = get(_PM.var(pm, n),   :qs, Dict()); _PM._check_var_keys(qs, bus_storage, "reactive power", "storage")
    qsw  = get(_PM.var(pm, n),  :qsw, Dict()); _PM._check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    q_dc = get(_PM.var(pm, n), :q_dc, Dict()); _PM._check_var_keys(q_dc, bus_arcs_dc, "reactive power", "dcline")
    bs   = get(_PM.var(pm, n),   :bs, Dict()); _PM._check_var_keys(bs, bus_shunts, "reactive power", "shunt")
    
    gs = Dict(k => _PM.ref(pm, n, :shunt, k, "gs") for k in bus_shunts)
    pd = Dict(k => _PM.ref(pm, n, :load, k, "pd") for k in bus_loads)
    qd = Dict(k => _PM.ref(pm, n, :load, k, "qd") for k in bus_loads)
    
    cstr = JuMP.@constraint(pm.model,
        sum(p[a] for a in bus_arcs)
        + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(psw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd[d] for d in bus_loads)
        - sum(gs[s] for s in bus_shunts)*vm^2
    )

    csti = JuMP.@constraint(pm.model,
        sum(q[a] for a in bus_arcs)
        + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(qsw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(qg[g] for g in bus_gens)
        - sum(qs[s] for s in bus_storage)
        - sum(qd[d] for d in bus_loads)
        + sum(bs[s] for s in bus_shunts)*vm^2
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


"""
Creates Ohms constraints with variables for complex transformation ratio (y post fix indicates  Y is in rectangular form)
```
p[f_idx] ==  (g+g_fr)/tm*v[f_bus]^2 + (-g)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus]-ta)) + (-b)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]-ta))
q[f_idx] == -(b+b_fr)/tm*v[f_bus]^2 - (-b)/tm*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus]-ta)) + (-g)/tm*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]-ta))
```
"""
function constraint_ohms_y_oltc_from(pm::AbstractACPModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr)
    p_fr  = var(pm, n, :p, f_idx)
    q_fr  = var(pm, n,  :q, f_idx)
    vm_fr = var(pm, n, :vm, f_bus)
    vm_to = var(pm, n, :vm, t_bus)
    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)
    tm = var(pm, n, :tm, f_idx[1])    
    index = f_idx[1]
    ta = ref(pm, :branch, index)["shift"]

    JuMP.@constraint(pm.model, p_fr ==  (g+g_fr)/tm^2*vm_fr^2 + (-g)/tm*(vm_fr*vm_to*cos(va_fr-va_to-ta)) + (-b)/tm*(vm_fr*vm_to*sin(va_fr-va_to-ta)) )
    JuMP.@constraint(pm.model, q_fr == -(b+b_fr)/tm^2*vm_fr^2 - (-b)/tm*(vm_fr*vm_to*cos(va_fr-va_to-ta)) + (-g)/tm*(vm_fr*vm_to*sin(va_fr-va_to-ta)) )
end

"""
Creates Ohms constraints with variables for complex transformation ratio (y post fix indicates  Y is in rectangular form)
```
p[t_idx] ==  (g+g_to)*v[t_bus]^2 + (-g)/tm*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus]+ta)) + (-b)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus]+ta))
q[t_idx] == -(b+b_to)*v[t_bus]^2 - (-b)/tm*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus]+ta)) + (-g)/tm*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus]+ta))
```
"""
function constraint_ohms_y_oltc_to(pm::AbstractACPModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to)
    p_to  = var(pm, n,  :p, t_idx)
    q_to  = var(pm, n,  :q, t_idx)
    vm_fr = var(pm, n, :vm, f_bus)
    vm_to = var(pm, n, :vm, t_bus)
    va_fr = var(pm, n, :va, f_bus)
    va_to = var(pm, n, :va, t_bus)
    tm = var(pm, n, :tm, f_idx[1])
    index = f_idx[1]
    ta = ref(pm, :branch, index)["shift"]

    JuMP.@constraint(pm.model, p_to ==  (g+g_to)*vm_to^2 + -g/tm*(vm_to*vm_fr*cos(va_to-va_fr+ta)) + -b/tm*(vm_to*vm_fr*sin(va_to-va_fr+ta)) )
    JuMP.@constraint(pm.model, q_to == -(b+b_to)*vm_to^2 - -b/tm*(vm_to*vm_fr*cos(va_to-va_fr+ta)) + -g/tm*(vm_to*vm_fr*sin(va_to-va_fr+ta)) )
end
