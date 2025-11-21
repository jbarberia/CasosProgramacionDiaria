@testset failfast=true "Estimador de estado" begin
    fecha = DateTime(2025, 6, 6, 20, 00)  # 2025-06-06 20:00
    prog = get_programacion_diaria(fecha)
    data = get_base_case(fecha)
    # map_generators_to_case!(data, prog)
    
    set_ac_pf_start_values!(data)    
    results = solve_ac_pf(data, optimizer)
    # results = run_state_estimation(data, ACPPowerModel, Ipopt.Optimizer)

    # verify if is solved
    @test results["termination_status"] in (LOCALLY_SOLVED, OPTIMAL)
    @test results["primal_status"] == FEASIBLE_POINT
    
    solution = results["solution"]
    
end
