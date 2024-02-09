group = "all" 

if group == "fields" || group == "all"
    println(1)
    include("test_fields.jl")
end

if group == "grids" || group == "all"
    include("test_grids.jl")
end

if group == "melt" || group == "all"
    include("test_melt.jl")
end

if group == "models" || group == "all"
    include("test_models.jl")
end

if group == "outputs" || group == "all"
    include("test_outputting.jl")
end

if group == "simulations" || group == "all"
    include("test_simulations.jl")
end

if group == "timesteppingparams" || group == "all"
    include("test_timesteppingparams.jl")
end

if group == "utils" || group == "all"
    include("test_utils.jl")
end

if group == "kronecker" || group == "all"
    include("test_kronecker.jl")
end

