


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

    flows = calc_branch_flow_ac(data)["branch"]    
    for (i, brn) in data["branch"]
        brn["tm_start"] = brn["tap"]        
        brn["tm_min"] = !haskey(brn, "tm_min") ? brn["tap"] : brn["tm_min"] # brn["tap"] * 0.97
        brn["tm_max"] = !haskey(brn, "tm_max") ? brn["tap"] : brn["tm_max"] # brn["tap"] * 1.03

        brn["pf_start"] = flows[i]["pf"]
        brn["pt_start"] = flows[i]["pt"]
        brn["qf_start"] = flows[i]["qf"]
        brn["qt_start"] = flows[i]["qt"]
    end

    for (i, shunt) in data["shunt"]
        shunt["bs_start"] = shunt["bs"]
        shunt["bs_min"] = !haskey(shunt, "bs_min") ? shunt["bs"] : shunt["bs_min"]
        shunt["bs_max"] = !haskey(shunt, "bs_max") ? shunt["bs"] : shunt["bs_max"]
        
        if get(shunt, "mode", 0) == 0
            shunt["bs_min"] = shunt["bs"]
            shunt["bs_max"] = shunt["bs"]
        end        
    end
end


function set_load_bounds!(data::Dict{String, Any})
    for (i, load) in data["load"]

        # Demandas de Aluar fijas
        aluar_source_id = [
            ["LO", 268, "1 "],
            ["LO", 269, "1 "],
            ["LO", 217, "1 "],
            ["LO", 193, "1 "],
        ]
        if load["source_id"] in aluar_source_id
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
    # opciones para hacer robusto el cambio de topes
    psspy.solution_parameters_4(
        intgar2=100,
        intgar4=5,
        realar13=0.8, 
        realar14=0.01
    )
    psspy.rsol()
    psspy.fnsl(options1=0, options5=0)  # locked
    psspy.fnsl(options1=0, options5=1)  # locked + shunt
    @assert psspy.solved() == 0
    
    psspy.fnsl(options1=1, options5=0)  # stepping
    psspy.fnsl(options1=1, options5=0)  # stepping
    psspy.fnsl(options1=1, options5=0)  # stepping
    psspy.fnsl(options1=0, options5=1)  # locked + shunt
    psspy.fnsl(options1=1, options5=0)  # stepping
    psspy.fnsl(options1=1, options5=1)  # stepping + shunt
    psspy.fnsl(options1=0, options5=0)  # locked
    if psspy.solved() != 0
        psspy.save("debug.sav")
    end
    @assert psspy.solved() == 0
    
end

"Devuelve el control conjunto en ezeiza"
function _compensadores_ezeiza()
    ierr, vm_ez = psspy.busdat(3000, "PU")
    
    # COMPENSADORES
    psspy.plant_chng_4(3651,0, intgar1=3000, realar1=vm_ez)
    psspy.plant_chng_4(3652,0, intgar1=3000, realar1=vm_ez)
    psspy.plant_chng_4(3653,0, intgar1=3000, realar1=vm_ez)
    psspy.plant_chng_4(3654,0, intgar1=3000, realar1=vm_ez)
    psspy.plant_chng_4(3655,0, intgar1=3000, realar1=vm_ez)
    psspy.plant_chng_4(3656,0, intgar1=3000, realar1=vm_ez)

    # GENELBA
    psspy.plant_chng_4(3641, 0, intgar1=3000, realar1=vm_ez)
    psspy.plant_chng_4(3642, 0, intgar1=3000, realar1=vm_ez)
    psspy.plant_chng_4(3643, 0, intgar1=3000, realar1=vm_ez)
    psspy.plant_chng_4(3647, 0, intgar1=3000, realar1=vm_ez)
    psspy.plant_chng_4(3658, 0, intgar1=3000, realar1=vm_ez)
    psspy.plant_chng_4(3690, 0, intgar1=3000, realar1=vm_ez)
end

"""
Exporta el caso a PSSE.
Arma ajustes basicos de control que se podrian perder en el caso.
"""
function export_case(data, filename)
    base_case = data["base_case"]
    psspy.case(base_case)
    psspy.progress_output(6)
    build_psse_data(data)
    psspy.progress_output(1)
    
    _compensadores_ezeiza()
    _flujo_de_carga_con_controles()

    psspy.save(filename)
end
