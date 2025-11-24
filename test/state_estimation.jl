@testset failfast=true "Estimador de estado" begin
    fecha = DateTime(2025, 6, 6, 20, 00)  # 2025-06-06 20:00
    prog = get_programacion_diaria(fecha)
    data = get_base_case(fecha)
    map_generators_to_case!(data, prog)
    map_flows_to_case!(data, prog)
    
    # TODO en funcion del nivel de tension ser mas restrictivo
    # de momento seria lo suficientemente loose.
    for (i, bus) in data["bus"]
        bus["vmax"] = 1.20
        bus["vmin"] = 0.80
    end

    # TODO encontrar mejores bordes para las demandas
    # for (i, load) in data["load"]
    #     load["pmin"] = load["pd"] * -2.0
    #     load["pmax"] = load["pd"] *  2.0
    #     load["qmin"] = load["qd"] * -2.0
    #     load["qmax"] = load["qd"] *  2.0
    # end

    set_ac_pf_start_values!(data)        
    results = run_state_estimation(data, ACPPowerModel, optimizer)

    # verify if is solved
    @test results["termination_status"] in (LOCALLY_SOLVED, OPTIMAL)
    @test results["primal_status"] == FEASIBLE_POINT
    
    # verify quality of solution
    solution = results["solution"]
    
    for (i, sol_bus) in solution["bus"]
        vm = sol_bus["vm"]
        @test vm <= data["bus"][i]["vmax"] 
        @test vm >= data["bus"][i]["vmin"] 
    end
    
    for (i, sol_gen) in solution["gen"]        
        pg = sol_gen["pg"]
        qg = sol_gen["qg"]
        @test pg <= data["gen"][i]["pmax"] 
        @test pg >= data["gen"][i]["pmin"]
    end

    # export solution    
    update_data!(data, solution)    
    base_case = data["base_case"]
    psspy.case(base_case)
    build_psse_data(data)
    psspy.save("foo.sav")
end
