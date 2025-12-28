

"""
Objetivo que penaliza desvios sin peso
"""
function objective_measurement_quadratic_loss(pm::_PM.AbstractPowerModel, nw=nw_id_default)
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

    return loss / measures
end


"""
Totales por area
"""
function objective_area_quadratic_loss(pm::_PM.AbstractPowerModel, nw=nw_id_default)
    n = 0
    loss = 0.0

    pd = var(pm, nw, :pd)
    area_load = ref(pm, nw, :area_load)
    
    area_totals = ref(pm, nw, :area_totals)
    for (i, area_total) in area_totals
        subtotal = 0.0
        for area in area_total["areas"]
            for index in area_load[area]
                subtotal += pd[index]
            end
        end

        loss += (subtotal - area_total["pd"])^2
        n += 1
    end

    return loss / n
end


function objective_transformer_voltage_control(pm::_PM.AbstractPowerModel, nw=nw_id_default)
    objective = 0.0
    n = 0
    for (i, brn) in ref(pm, nw, :branch)
        if haskey(brn, "control_bus")
            control_bus = brn["control_bus"]
            control_bus == 0 && continue

            u    = var(pm, nw, :vm, control_bus)
            umax = brn["vm_max"]
            umin = brn["vm_min"]

            rho = 0.01
            alpha = 200
            p_low  = rho/alpha * log(1+ exp(alpha * (umin - u)))
            p_high = rho/alpha * log(1+ exp(alpha * (u - umax)))

            objective += (p_low + p_high)^2
            n += 1
        end
    end
    return n > 0 ? objective / n : 0.0
end


function objective_transformer_movement(pm::_PM.AbstractPowerModel, nw=nw_id_default)
    eps  = 0.0125
    loss = 0.0
    n = 0
    for (i, branch) in ref(pm, :branch)

        source_id = branch["source_id"]
        # source_id == ["T3", 211, 261, 222, "2 ", 1] && Main.@infiltrate

        tm = var(pm, nw, :tm, i)
        is_fixed(tm) && continue
        t0 = branch["tm_start"]
        dt = tm - t0
        loss += dt^2 / (dt^2 + eps^2)
        n += 1
    end
    return n > 0 ? loss / n : 0.0
end


function objective_shunt_voltage_control(pm::_PM.AbstractPowerModel, nw=nw_id_default)
    objective = 0.0
    n = 0
    for (i, shunt) in ref(pm, nw, :shunt)

        # ñshunt["source_id"][1] == "SWS" && Main.@infiltrate
        if haskey(shunt, "mode")
            shunt["mode"] <= 0 && continue
            bus = shunt["shunt_bus"]

            u    = var(pm, nw, :vm, bus)
            umax = shunt["vm_max"]
            umin = shunt["vm_min"]

            rho = 0.01
            alpha = 200
            p_low  = rho/alpha * log(1+ exp(alpha * (umin - u)))
            p_high = rho/alpha * log(1+ exp(alpha * (u - umax)))

            objective += (p_low + p_high)^2
            n += 1
        end
    end
    return n > 0 ? objective / n : 0.0
end


function objective_shunt_movement(pm::_PM.AbstractPowerModel, nw=nw_id_default)
    eps  = 0.5
    loss = 0.0
    n = 0
    for (i, shunt) in ref(pm, :shunt)
        bs = var(pm, nw, :bs, i)
        is_fixed(bs) && continue
        b0 = shunt["bs_start"]
        dt = bs - b0
        loss += dt^2 / (dt^2 + eps^2)
        n += 1
    end
    return n > 0 ? loss / n : 0.0
end


function objective_bus_voltage_band(pm::_PM.AbstractPowerModel, nw=nw_id_default)
    objective = 0
    n = 0
    eta = 1e-4
    for (i, bus) in ref(pm, nw, :bus)
        v_lim = 1.0
        dv = max(bus["vmax"] - bus["vmin"], eta)
        vm = var(pm, nw, :vm, i)

        u = vm
        umin = bus["vmin"]
        umax = bus["vmax"]

        # generadores en 0.95 - 1.05
        if length(ref(pm, nw, :bus_gens, i)) > 0
            umin = 0.95
            umax = 1.05
        end

        rho = 0.01
        alpha = 200
        p_low  = rho/alpha * log(1+ exp(alpha * (umin - u)))
        p_high = rho/alpha * log(1+ exp(alpha * (u - umax)))
        objective += (p_low + p_high)^2

        # objective += (vm - v_lim)^2 / dv
        n += 1

    end
    return objective / n
end


function objective_gen_reactive_power_reserve(pm::_PM.AbstractPowerModel, nw=nw_id_default)
    loss = 0.0
    n = 0

    for (i, gen) in ref(pm, nw, :gen)
        q = var(pm, nw, :qg, i)
        q_max = gen["qmax"]
        q_min = gen["qmin"]

        if q_max > 0
            q_max *= 0.8
        end

        if q_min < 0
            q_min *= 0.8
        end

        eps = 1e-2
        rho = 0.01
        alpha = 200
        loss += rho/alpha * log(1 + exp(alpha * (q_min - q)))
        loss += rho/alpha * log(1 + exp(alpha * (q - q_max)))
        n += 1
    end

    return loss / n
end


function objective_transformer_GBA(pm::_PM.AbstractPowerModel, nw=nw_id_default)
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

    return loss / n
end

