


"""
Setea limites de tensión en barras

 5 % para 500 kV
10 % para 220 kV
20 % para 132 kV
20 % para el resto
"""
function set_voltage_bounds!(data)
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
end


"pf con taps y shunt moviles"
function _flujo_de_carga_con_controles()
    psspy.fnsl(options1=0, options5=0)  # locked
    @assert psspy.solved() == 0

    psspy.fnsl(options1=2, options5=0)  # direct
    psspy.fnsl(options1=1, options5=0)  # stepping
    psspy.fnsl(options1=1, options5=2)  # stepping + cont shunt
    psspy.fnsl(options1=1, options5=1)  # stepping + all shunt
    psspy.fnsl(options1=0, options5=0)  # locked to save the sol
    @assert psspy.solved() == 0
end

"Devuelve el control conjunto en ezeiza"
function _compensadores_ezeiza()
    psspy.plant_chng_4(3651,0, intgar1=3000, realar1=1.0)
    psspy.plant_chng_4(3652,0, intgar1=3000, realar1=1.0)
    psspy.plant_chng_4(3653,0, intgar1=3000, realar1=1.0)
    psspy.plant_chng_4(3654,0, intgar1=3000, realar1=1.0)
    psspy.plant_chng_4(3655,0, intgar1=3000, realar1=1.0)
    psspy.plant_chng_4(3656,0, intgar1=3000, realar1=1.0)
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
