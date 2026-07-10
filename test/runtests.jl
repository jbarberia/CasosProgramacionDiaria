using CasosProgramacionDiaria
using PowerModels
using Ipopt
using JuMP
using DataFrames
using Dates
using Test
using Logging

optimizer = JuMP.optimizer_with_attributes(
    Ipopt.Optimizer,
    "tol"=>1e-4,
    "max_iter"=>200,
    "print_level"=>5,
    "nlp_scaling_method"=>"none", # al parecer falla el caso aca
)

# logger
open("logger.log", "w") do log_file
    test_logger = SimpleLogger(log_file, Logging.Warn)
    with_logger(test_logger) do
        include("web_downloader.jl")
        include("component_mapper.jl")
        include("state_estimation.jl")
        # include("escenarios.jl")
    end
end

# elimina zips
rm.(filter(x -> endswith(x, ".zip"), readdir(".")))
rm.(filter(x -> endswith(x, ".sav"), readdir(".")))
rm.(filter(x -> endswith(x, ".log"), readdir(".")))
