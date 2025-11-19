@testset failfast=true "web_downloader" begin
     
    fecha = DateTime(2025, 6, 6, 20, 00)  # 2025-06-06 20:00
    prog = get_programacion_diaria(fecha)
    
    
    @testset "tipo de datos" begin
        @test prog isa Dict{String, DataFrame}
    end
    


end
