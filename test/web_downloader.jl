@testset failfast=true "web_downloader" begin
    fecha = DateTime(2025, 6, 6, 20, 00)  # 2025-06-06 20:00

    zipfile = CasosProgramacionDiaria.pd_zip_filename(fecha)
    isfile(zipfile) && rm(zipfile)

    # descarga
    prog1 = get_programacion_diaria(fecha)
    @test prog1 isa Dict{String, DataFrame}
    @test isfile(zipfile)
    
    # usa cache
    prog2 = get_programacion_diaria(fecha)
    @test prog2 isa Dict{String, DataFrame} 
end


@testset failfast=true "lowercase tables" begin
    fecha = DateTime(2026, 03, 07, 00, 00)  # 2026-03-07

    zipfile = CasosProgramacionDiaria.pd_zip_filename(fecha)
    isfile(zipfile) && rm(zipfile)

    prog1 = get_programacion_diaria(fecha)
    
    for (k, df) in prog1        
        for name in names(df)
            @test name == uppercase(name)
        end
    end
end
