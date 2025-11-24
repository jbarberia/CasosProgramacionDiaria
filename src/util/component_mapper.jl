"""
Funciones para mapear los componentes de una programacion diaria al caso
"""

"""
Obtiene el mapeo manual de componentes de la PD hacia el caso de PSSE
"""
function get_configuration_data()
    root = joinpath(@__DIR__, "..", "config")

    archivos = [
        "maqhid",
        "valores_generadores",
        "balance",
        "intercambios",
    ]

    config_data = Dict{String, Any}()

    for archivo in archivos
        config_data[archivo] = open("$root/$archivo.json") do io 
            data = JSON3.read(io, Dict{String, Any})
        end
    end

    # adjust space padding id in machines
    for category in ["maqhid", "valores_generadores"]
        for (k, v) in config_data[category]
            config_data[category][k] = map(a -> [a[1], rpad(a[2], 2, " ")], v)
        end
    end
    
    return config_data
end


"""
Devuelve el caso que mas se acerca al periodo de analisis
"""
function get_base_case(fecha::DateTime)
    root = joinpath(@__DIR__, "..", "cases")

    casos_base = Dict(
        "verano" => Dict(
            "valle" => "$root/ver2526va.sav",
            "resto" => "$root/ver2526pid.sav",
            "pico"  => "$root/ver2526pin.sav",
        ),    
        "invierno" => Dict(
            "valle" => "$root/inv25va.sav",
            "resto" => "$root/inv25hr.sav",
            "pico"  => "$root/inv25pi.sav",
        ),
    )
    @show root
    periodo = (4 < month(fecha) < 9) ? "invierno" : "verano"
    escenario = if 6 < hour(fecha) <= 18
        "resto"
    elseif 18 < hour(fecha) <= 24
        "pico"
    else
        "valle"
    end

    # open the case in psse
    filename = casos_base[periodo][escenario]
    psspy.psseinit()
    psspy.case(filename)

    # parse to pm
    data = build_pm_data()
    merge_zi_connected_buses!(data)
    correct_pv_bus_type!(data)
    
    # set reference for rebuilding
    data["base_case"] = filename
    data["datetime"]  = fecha
        
    return data
end


"""
Devuelve el caso que mas se acerca al periodo de analisis
"""
function get_base_case(programacion::Dict, hora::Time)
    date_string = programacion["FECHA_REVISTA"][1, "FECHA"]
    parsed_date = Date(date_string, dateformat"dd/mm/yyyy") + hora
    return get_base_case(parsed_date)
end


"""
Toma la programacion diaria y mapeo los valores de generadores al caso
"""
function map_generators_to_case!(data, programacion)
    config = get_configuration_data()
    hora_str = hora_str = "H" * lpad(hour(data["datetime"]), 1, '0')

    # Mapeo generadores
    source2index = Dict(gen["source_id"][2:end] => i for (i, gen) in data["gen"])
    for (i, gen) in data["gen"]
        gen["nemo"] = ""
    end
    
    # Prendo maquinas hidro
    for (nemo, n_maquinas) in programacion["MAQHID_DESPACHADAS"][!, ["CENTRAL", hora_str]] |> eachrow
        source_ids = get(config["maqhid"], nemo, nothing)
        
        if source_ids === nothing
            @info "máquina hidro $nemo no encontrada"
            continue
        end
        
        maq_prendidas = 0
        for source_id in source_ids
            idx = source2index[source_id]
            
            
            
            if maq_prendidas < n_maquinas
                data["gen"][idx]["gen_status"] = 1
                maq_prendidas += 1
                
                # fuerzo que sea barra del tipo 2
                bus_i = data["gen"][idx]["gen_bus"]
                bus_type = data["bus"]["$bus_i"]["bus_type"]                
                data["bus"]["$bus_i"]["bus_type"] = max(2, bus_type)            
            else
                data["gen"][idx]["gen_status"] = 0
            end
        end
    end

    # Coloco valores de generacion
    for (nemo, p_des) in programacion["VALORES_GENERADORES"][!, ["GRUPO", hora_str]] |> eachrow    
        source_ids = get(config["valores_generadores"], nemo, nothing)
        
        if source_ids === nothing
            if p_des > 0
                @info "máquina $nemo ($p_des MW) no encontrada"
            end
            continue
        end
        
        es_hidro = false
        maquinas_despachadas = 0
        pg_max = 0
        for source_id in source_ids
            idx = source2index[source_id]
            bus_i = data["gen"][idx]["gen_bus"]
            bus = data["bus"]["$bus_i"]
            es_hidro = bus["owner"] == 6 || bus["owner"] == 901
            maquinas_despachadas += data["gen"][idx]["gen_status"]
            pg_max += data["gen"][idx]["pmax"]
        end
        # es_hidro && @info "$nemo tiene $maquinas_despachadas máquinas despachadas"

        for source_id in source_ids
            idx = source2index[source_id]
            bus_i = data["gen"][idx]["gen_bus"]        
            bus = data["bus"]["$bus_i"]
            data["gen"]["$idx"]["nemo"] = nemo
            if p_des == 0
                data["gen"]["$idx"]["gen_status"] = 0
                data["gen"]["$idx"]["pg_des"] = 0
            else
                if es_hidro                    
                    data["gen"]["$idx"]["pg_des"] = p_des / maquinas_despachadas / data["baseMVA"]
                else                
                    data["gen"]["$idx"]["gen_status"] = 1
                    data["gen"]["$idx"]["pg_des"] = p_des / length(source_ids) / data["baseMVA"]                               
                    bus_type = data["bus"]["$bus_i"]["bus_type"]
                    data["bus"]["$bus_i"]["bus_type"] = max(2, bus_type)
                end
            end
        end

        # if pg_des > pg_max set to pg_max.
        for (i, gen) in data["gen"]
            !haskey(gen, "pg_des") && continue
            pg_max = gen["pmax"]
            pg_des = gen["pg_des"]
            source_id = gen["source_id"][2:end]
            if pg_des > pg_max
                @warn "Generator $i - $source_id with pg_des ($pg_des) out of bounds, setting to pmax $(pg_max)"
                gen["pg_des"] = pg_max
            end
        end
    end
end

"""
Mapea los datos a la entrada flows, para poder tener mas control
sobre interfaces y limites inter-areas que involucren mas de una linea.
"""
function map_flows_to_case!(data, programacion)
    baseMVA = data["baseMVA"]
    config = get_configuration_data()
    hora_str = hora_str = "H" * lpad(hour(data["datetime"]), 1, '0')
    
    flujo_programado = Dict{Any, Any}()
    datos_interconexiones = programacion["INTERCONEXIONES"][!, ["NODO1", "NODO2", hora_str]]
    for (nodo1, nodo2, valor) in datos_interconexiones |> eachrow                
        flujo_programado[[nodo1, nodo2]] = valor
        flujo_programado[[nodo2, nodo1]] = -valor
    end
    
    source2index = Dict(brn["source_id"][2:end] => i for (i, brn) in data["branch"])
    data["flows"] = Dict{String, Any}()
    
    i = 1
    for (name, dato_intercambio) in config["intercambios"]        
        indices = []
        for source_id in dato_intercambio["PSSE"]
            idx = source2index[source_id[2:end]]
            brn = data["branch"][idx]
            f_bus = brn["f_bus"]
            t_bus = brn["t_bus"]

            if f_bus == source_id[2]
                push!(indices, (parse(Int, idx), f_bus, t_bus))
            else
                push!(indices, (parse(Int, idx), t_bus, f_bus))
            end
        end
        
        p_des = 0
        for interconexion in dato_intercambio["PD"]
            p_des += flujo_programado[interconexion] / baseMVA
        end
        
        data["flows"][string(i)] = Dict(
            "index" => i,
            "branches" => indices,
            "p_des" => p_des,
            "name" => name,
        )
        i += 1
    end
end


"""
Escala la demanda para que el caso cierre
"""
function map_loads_to_case!(data, programacion)
    config = get_configuration_data()
    hora_str = hora_str = "H" * lpad(hour(data["datetime"]), 1, '0')
    
    # obtengo programacion de demanda
    balance = programacion["BALANCE"]
    p_objetivo = filter(row -> row.VARIABLE == "Demanda Neta", balance)[!, ["RGE", hora_str]]
    p_objetivo[!, hora_str] /= data["baseMVA"]
    p_objetivo = p_objetivo |> eachrow |> Dict

    # mapeo demandas a cada region electrica    
    area2rge = Dict(area => rge for (rge, areas) in config["balance"]["RGE"] for area in areas)
    loads_in_rge = Dict(rge => [] for rge in unique(values(area2rge)))
    source_id2load = Dict()
    for (i, load) in data["load"]
        load["status"] == 0 && continue

        bus_i = load["load_bus"]
        bus = data["bus"]["$bus_i"]
        area = bus["area"]

        # referencia para poder agrupar demandas
        if haskey(area2rge, area)
            rge = area2rge[area]
            push!(loads_in_rge[rge], i)
        end

        # referencia para trabajar sobre demandas particulares
        source_id2load[load["source_id"][2:end]] = load
    end

    # calculo los totales y coeficientes
    for (rge, loads) in loads_in_rge
        
        # tipo de demandas
        in_service_loads = [data["load"][i] for i in loads if data["load"][i]["status"] == 1]
        p_escalable = sum(load["pd"] for load in in_service_loads if load["scalable"])
        p_no_escalable = sum(load["pd"] for load in in_service_loads if !load["scalable"])

        # factor de ajuste
        factor = (p_objetivo[rge] - p_no_escalable) / (p_escalable)
        @info "Se corrige demanda en $rge en un $(round(factor * 100)) % - Objetivo: $(round(p_objetivo[rge] * 100)) MW"
        
        # correcciones en casos border
        if factor < 0 && rge == "PAT"
            cubas_aluar_pat = [
                [268, "1 "],
                [269, "1 "],
                [217, "1 "],
                [193, "1 "],
                ]
                p_cortada = 0
                for id in cubas_aluar_pat                    
                    load = source_id2load[id]
                    p_load = load["pd"]
                    p_cortada += p_load
                    factor = (p_objetivo[rge] - (p_no_escalable - p_cortada)) / (p_escalable)

                idx = load["index"]
                data["load"]["$idx"]["status"] = 0
                
                @info "Se apaga una cuba de aluar ($id) por $(round(p_load * 100, digits=0)) MW"
                if factor > 0
                    break
                end
            end
        end

        # aplico factor de ajuste
        nueva_demanda = 0
        for load in in_service_loads
            load["status"] == 0 && continue
            !load["scalable"] && continue

            idx = load["index"]
           
            data["load"]["$idx"]["pd"] = data["load"]["$idx"]["pd"] * factor
            data["load"]["$idx"]["qd"] = data["load"]["$idx"]["qd"] * factor
        end        
    end
end


"""
Genera una entrada en el data dict de PowerModels
"1" => {indices = [1, 2, 3], p_des = 1.0, name = name}
"""
function map_desired_interchanges!(data, programacion)
    baseMVA = data["baseMVA"]
    config = get_configuration_data()
    hora_str = hora_str = "H" * lpad(hour(data["datetime"]), 1, '0')

    intercambios_programados = Dict()
    for (n1, n2, p) in programacion["INTERCONEXIONES"][!, ["NODO1", "NODO2", hora_str]] |> eachrow        
        intercambios_programados[[n1, n2]] =  p
        intercambios_programados[[n2, n1]] = -p
    end
    
    mapstring2branch = Dict(br["source_id"] => i for (i, br) in data["branch"])
    data["interchange"] = Dict{String, Any}()
    for (i, (name, intercambios)) in enumerate(config["intercambios"])
        branches = [mapstring2branch[x] for x in intercambios["PSSE"]]
        
        desired = 0
        for intercambio in intercambios["PD"]
            desired += intercambios_programados[intercambio] / baseMVA
        end
        
        data["interchange"][string(i)] = Dict(
            "branches" => branches,
            "p_desired" => desired,
            "name" => name
        )
            
    end
end
