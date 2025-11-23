

function variable_load_power(pm::AbstractPowerModel; kwargs...)
    variable_load_power_real(pm; kwargs...)
    variable_load_power_imag(pm; kwargs...)
end


function variable_load_power_real(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    pd = var(pm, nw)[:pd] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :load)], base_name="$(nw)_pd",
        start = comp_start_value(ref(pm, nw, :load, i), "pd_start")
    )

    if bounded
        for (i, load) in ref(pm, nw, :load)
            JuMP.set_lower_bound(pd[i], load["pmin"])
            JuMP.set_upper_bound(pd[i], load["pmax"])
        end
    end

    report && _IM.sol_component_value(pm, pm_it_sym, nw, :load, :pd, ids(pm, nw, :load), pd)
end


function variable_load_power_imag(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    qd = var(pm, nw)[:qd] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :load)], base_name="$(nw)_qd",
        start = comp_start_value(ref(pm, nw, :load, i), "qd_start")
    )

    if bounded
        for (i, load) in ref(pm, nw, :load)
            JuMP.set_lower_bound(qd[i], load["qmin"])
            JuMP.set_upper_bound(qd[i], load["qmax"])
        end
    end

    report && _IM.sol_component_value(pm, pm_it_sym, nw, :load, :qd, ids(pm, nw, :load), qd)
end




function variable_load_area_factor(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    area_load_factor = var(pm, nw)[:area_load_factor] = JuMP.@variable(pm.model,
        [i in ref(pm, nw, :area)], base_name="$(nw)_area_factor",
        start = 1.0
    )

    if bounded
        for i in ref(pm, nw, :area)
            JuMP.set_lower_bound(area_load_factor[i], 0.5)
            JuMP.set_upper_bound(area_load_factor[i], 1.5)
        end
    end

    report && _IM.sol_component_value(pm, pm_it_sym, nw, :area, :area_load_factor, ref(pm, nw, :area), area_load_factor)
end


function variable_load_zone_factor(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    zone_load_factor = var(pm, nw)[:zone_load_factor] = JuMP.@variable(pm.model,
        [i in ref(pm, nw, :zone)], base_name="$(nw)_zone_factor",
        start = 1.0
    )

    if bounded
        for i in ref(pm, nw, :zone)
            JuMP.set_lower_bound(zone_load_factor[i], 0.5)
            JuMP.set_upper_bound(zone_load_factor[i], 1.5)
        end
    end

    report && _IM.sol_component_value(pm, pm_it_sym, nw, :zone, :zone_load_factor, ref(pm, nw, :zone), zone_load_factor)
end


function variable_load_bus_factor(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    bus_load_factor = var(pm, nw)[:bus_load_factor] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :bus)], base_name="$(nw)_bus_factor",
        start = 1.0
    )

    if bounded
        for i in ids(pm, nw, :bus)
            JuMP.set_lower_bound(bus_load_factor[i], 0.5)
            JuMP.set_upper_bound(bus_load_factor[i], 1.5)
        end
    end

    report && _IM.sol_component_value(pm, pm_it_sym, nw, :bus, :bus_load_factor, ids(pm, nw, :bus), bus_load_factor)
end
