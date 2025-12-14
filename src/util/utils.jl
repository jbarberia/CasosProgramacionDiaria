


"""
Setea limites de tensión en barras

 5 % para 500 kV
10 % para 220 kV
20 % para 132 kV
20 % para el resto
"""
function set_voltage_bounds!(data::Dict{String, Any})
    for (i, bus) in data["bus"]
        base_kv = bus["base_kv"]
    
        if base_kv >= 500
            bus["vmax"] = 1.05
            bus["vmin"] = 0.95
        elseif base_kv >= 220
            bus["vmax"] = 1.10
            bus["vmin"] = 0.90
        elseif base_kv >= 132
            bus["vmax"] = 1.20
            bus["vmin"] = 0.80
        else
            bus["vmax"] = 1.20
            bus["vmin"] = 0.80
        end
    end

    for (i, gen) in data["gen"]
        gen_bus = gen["gen_bus"]
        data["bus"][string(gen_bus)]["vmax"] = 1.10
        data["bus"][string(gen_bus)]["vmin"] = 0.90
    end


end


"Pone valores iniciales"
function set_start_values!(data::Dict{String, Any})
for (i,bus) in data["bus"]
        bus["va_start"] = bus["va"]
        bus["vm_start"] = bus["vm"]
    end

    for (i,gen) in data["gen"]
        gen["pg_start"] = gen["pg"]
        gen["qg_start"] = gen["qg"]
    end
    
    for (i,load) in data["load"]
        load["pd_start"] = load["pd"]
        load["qd_start"] = load["qd"]
    end

    for (i, brn) in data["branch"]
        brn["tm_start"] = brn["tap"]        
        brn["tm_min"] = !haskey(brn, "tm_min") ? brn["tap"] : brn["tap"] * 0.98
        brn["tm_max"] = !haskey(brn, "tm_max") ? brn["tap"] : brn["tap"] * 1.02
    end
end



function set_load_bounds!(data::Dict{String, Any})
    for (i, load) in data["load"]

        # Demandas de Aluar fijas
        if load["load_bus"] in [268, 269, 217, 193]
            load["pd_min"] = load["pd"]
            load["pd_max"] = load["pd"]
            load["qd_min"] = load["qd"]
            load["qd_max"] = load["qd"]
        end
        
        # Servicios auxiliares fijos
        if load["load_owner"] in [3, 4, 5, 6, 7, 8, 9, 12, 14]
            load["pd_min"] = load["pd"]
            load["pd_max"] = load["pd"]
            load["qd_min"] = load["qd"]
            load["qd_max"] = load["qd"]
        end

        # Demanda residencial positiva
        if load["load_owner"] in [1, 2, 901]
            load["pd_min"] = 0
        end
    end
end



"pf con taps y shunt moviles"
function _flujo_de_carga_con_controles()
    psspy.rsol(
        options1=1,
        options2=0,
        options3=0,
        options4=0,
        options5=1,
        options6=0,
        options7=0,
        options8=0,
        options9=0,
        options10=0,
        realar1=500.0,
        realar2=5.0,
    )
    psspy.fnsl(options1=0, options5=0)  # locked
    @assert psspy.solved() == 0

    # opciones para hacer robusto el cambio de topes
    psspy.solution_parameters_4(
        intgar4=10,
        realar13=0.8, 
        realar14=0.02
    )
    # psspy.fnsl(options1=1, options5=0)  # stepping
    # psspy.fnsl(options1=0, options5=2)  # locked + cont shunt
    # psspy.fnsl(options1=0, options5=1)  # locked + all shunt
    # psspy.fnsl(options1=0, options5=0)  # locked to save the sol
    @assert psspy.solved() == 0
end

"Devuelve el control conjunto en ezeiza"
function _compensadores_ezeiza()
    ierr, vm_ez = psspy.busdat(3000, "PU")
    psspy.plant_chng_4(3651,0, intgar1=3000, realar1=vm_ez)
    psspy.plant_chng_4(3652,0, intgar1=3000, realar1=vm_ez)
    psspy.plant_chng_4(3653,0, intgar1=3000, realar1=vm_ez)
    psspy.plant_chng_4(3654,0, intgar1=3000, realar1=vm_ez)
    psspy.plant_chng_4(3655,0, intgar1=3000, realar1=vm_ez)
    psspy.plant_chng_4(3656,0, intgar1=3000, realar1=vm_ez)
end

"""
Exporta el caso a PSSE.
Arma ajustes basicos de control que se podrian perder en el caso.
"""
function export_case(data, filename)
    base_case = data["base_case"]
    psspy.case(base_case)
    build_psse_data(data)

    _compensadores_ezeiza()
    _flujo_de_carga_con_controles()

    psspy.save(filename)
end
