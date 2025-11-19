using CasosProgramacionDiaria
using PowerModels
using Ipopt
using JuMP
using DataFrames
using Dates
using Test

optimizer = JuMP.optimizer_with_attributes(
    Ipopt.Optimizer,
    "tol"=>1e-6,
    "max_iter"=>200,
    "print_level"=>1,
    "nlp_scaling_method"=>"none", # al parecer falla el caso aca
)

include("web_downloader.jl")
include("component_mapper.jl")

# elimina zips
rm.(filter(x -> endswith(x, ".zip"), readdir(".")))
