

@testset failfast=true "semana 50" begin
    fecha_0 = DateTime(2025, 12, 08, 00, 00)
    fecha_1 = DateTime(2025, 12, 08, 23, 00)

    prev_data = []

    for fecha in fecha_0:Hour(1):fecha_1
        
        prog = get_programacion_diaria(fecha)
        
        if length(prev_data) == 0
            data = get_base_case(fecha)
        else
            data = prepare_pm_case(prev_data[end], fecha)            
        end
    

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
        if length(prev_data) == 0
            set_start_values!(data)        
            results = run_voltage_correction(data, ACPPowerModel, optimizer)
            update_data!(data, results["solution"])
        end

        filename = Dates.format(fecha, "dd-mm-yyyy_HH") * ".sav"
        push!(prev_data, filename)
        
        solution = results["solution"]
        update_data!(data, solution)    
        export_case(data, filename)
    end
end
