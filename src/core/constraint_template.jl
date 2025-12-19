
function constraint_power_balance_with_variable_demand(pm::_PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    bus         = _PM.ref(pm, nw, :bus, i)
    bus_arcs    = _PM.ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = _PM.ref(pm, nw, :bus_arcs_dc, i)
    bus_arcs_sw = _PM.ref(pm, nw, :bus_arcs_sw, i)
    bus_gens    = _PM.ref(pm, nw, :bus_gens, i)
    bus_loads   = _PM.ref(pm, nw, :bus_loads, i)
    bus_shunts  = _PM.ref(pm, nw, :bus_shunts, i)
    bus_storage = _PM.ref(pm, nw, :bus_storage, i)
    
    bus_gs = Dict(k => _PM.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => _PM.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_power_balance_with_variable_demand(pm, nw, i, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_loads, bus_gs, bus_bs)
end


function constraint_power_balance_with_variable_shunt(pm::_PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    bus         = _PM.ref(pm, nw, :bus, i)
    bus_arcs    = _PM.ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = _PM.ref(pm, nw, :bus_arcs_dc, i)
    bus_arcs_sw = _PM.ref(pm, nw, :bus_arcs_sw, i)
    bus_gens    = _PM.ref(pm, nw, :bus_gens, i)    
    bus_loads   = _PM.ref(pm, nw, :bus_loads, i)
    bus_shunts  = _PM.ref(pm, nw, :bus_shunts, i)
    bus_storage = _PM.ref(pm, nw, :bus_storage, i)
    
    constraint_power_balance_with_variable_shunt(pm, nw, i, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_loads, bus_shunts)
end


function constraint_ohms_y_oltc_from(pm::AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]

    constraint_ohms_y_oltc_from(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr)
end


function constraint_ohms_y_oltc_to(pm::AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = calc_branch_y(branch)
    g_to = branch["g_to"]
    b_to = branch["b_to"]

    constraint_ohms_y_oltc_to(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to)
end


function constraint_fixed_load_power(pm::_PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    load = ref(pm, nw, :load, i)
    load_pd = load["pd"]
    load_qd = load["qd"]
    
    pd = get(var(pm, nw), :pd, nothing)
    qd = get(var(pm, nw), :qd, nothing)
    
    !isnothing(pd) && fix(pd[i], load_pd; force=true)
    !isnothing(qd) && fix(qd[i], load_qd; force=true)
end
