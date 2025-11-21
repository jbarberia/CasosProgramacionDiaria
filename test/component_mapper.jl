@testset failfast=true "component_mapper" begin
    fecha = DateTime(2025, 6, 6, 20, 00)  # 2025-06-06 20:00
    prog = get_programacion_diaria(fecha)
    data = get_base_case(fecha)
    
    @testset "base case" begin
        # check types
        @test data isa Dict
        
        set_ac_pf_start_values!(data)
        results = solve_ac_pf(data, optimizer)        

        # verify if is solved
        @test results["termination_status"] in (LOCALLY_SOLVED, OPTIMAL)
        @test results["primal_status"] == FEASIBLE_POINT
    end
    
    @testset "desired generation" begin        
        map_generators_to_case!(data, prog)
        gen_source_id = Dict(gen["source_id"][2:end] => gen for (k, gen) in data["gen"])
        
        @test isapprox(gen_source_id[[2628, "23"]]["pg_des"], 0.0)
        @test gen_source_id[[2628, "23"]]["gen_status"] == 0
        
        @test isapprox(gen_source_id[[2620, "1 "]]["pg_des"], 7.01)
        @test gen_source_id[[2620, "1 "]]["gen_status"] == 1
    end
end
