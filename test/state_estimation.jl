
function test_solution(data, results, outfile)
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

        if haskey(data["gen"][i], "pg_des")
            pg_des = data["gen"][i]["pg_des"]
            rel_error = pg / pg_des - 1
            rel_error *= 100
            source_id = data["gen"][i]["source_id"][2:end]
            
            rel_error > 100 && @show source_id, rel_error, (pg, pg_des)
        end

    end

    # export solution            
    export_case(data, outfile)
end


@testset failfast=true "Estimador de estado 2025-6-6 20:00" begin
    fecha = DateTime(2025, 6, 6, 20, 00)  # 2025-06-06 20:00    
    prog = get_programacion_diaria(fecha)
    data = get_base_case(fecha)
    
    set_voltage_bounds!(data)
    map_generators_to_case!(data, prog)
    map_flows_to_case!(data, prog)
    map_bounds_to_case!(data, prog)
    set_load_bounds!(data)

    # state estimation
    set_start_values!(data)        
    results = run_state_estimation(data, ACPPowerModel, optimizer)
    update_data!(data, results["solution"])
    
    # voltage control
    set_start_values!(data)        
    results = run_voltage_correction(data, ACPPowerModel, optimizer)
    update_data!(data, results["solution"])

    test_solution(data, results, "06-06-2025_H20.sav")
end


@testset failfast=true "Estimador de estado 2025-11-29 15:00" begin
    fecha = DateTime(2025, 11, 29, 15, 00)  # 2025-11-29 15:00    
    prog = get_programacion_diaria(fecha)
    data = get_base_case(fecha)
    
    set_voltage_bounds!(data)
    map_generators_to_case!(data, prog)
    map_flows_to_case!(data, prog)
    map_bounds_to_case!(data, prog)
    set_load_bounds!(data)

    # state estimation
    set_start_values!(data)        
    results = run_state_estimation(data, ACPPowerModel, optimizer)
    update_data!(data, results["solution"])
    
    # voltage control
    set_start_values!(data)        
    results = run_voltage_correction(data, ACPPowerModel, optimizer)
    update_data!(data, results["solution"])

    test_solution(data, results, "29-11-2025_H15.sav")
end

