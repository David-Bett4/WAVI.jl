```@meta
EditURL = "<unknown>/examples/planar_one_dimensional_flow.jl"
```

# Planar One-Dimensional Flow

This a WAVI.jl's simplest example:
flow down a flat plane in one horizontal dimension. This example demonstrates

  * How to load `WAVI.jl`.
  * How to instantiate an `WAVI.jl` model.
  * How to create simple `WAVI.jl` output.
  * How to time-step a model forward.
  * How to look at results.

## Install dependencies

First let's make sure we have all required packages installed.

using Pkg
Pkg.add("https://github.com/RJArthern/WAVI.jl"), Pkg.add(Plots)

````@example planar_one_dimensional_flow
using WAVI, Plots
````

## Instantiating and configuring a model
We first build a WAVI `model`, by passing it a grid, information about the problem we would like to solve.

Below, we build a grid with 300 grid points in the `x` direction. We use 2 grid points in the `y` direction (the minimum number of grid points in any dimension). This grid has a resolution of 12km.

````@example planar_one_dimensional_flow
grid = Grid(nx = 300, ny = 2, dx = 12000.0, dy = 12000.0);
nothing #hide
````

Next, we write a function which defines the WAVI.jl accepts both functions and arrays (of the same size as the grid) as bed inputs, but here we'll use a function for simplicity

````@example planar_one_dimensional_flow
function bed_elevation(x,y)
    B = 720 - 778.5 * x ./ (750e3);
    return B;
end
````

This bed drops a height of 778.5m in every 750km, which is a typical scale for an ice sheet in Antarctica.

Next we specify physical parameters via a `Params` object. In this case, we set the accumulation rate (the net snowfall).

````@example planar_one_dimensional_flow
params = Params(accumulation_rate = 0.3);
nothing #hide
````

Let's also set the thickness of the ice to be 300m everywhere, to start with. Initial conditions are set via `InitialConditions` objects

````@example planar_one_dimensional_flow
initial_conditions = InitialConditions(initial_thickness = 300. .* ones(grid.nx, grid.ny));
nothing #hide
````

Now we are ready to build a `Model` by assembling these pieces:

````@example planar_one_dimensional_flow
model = Model(grid = grid, bed_elevation = bed_elevation, params = params);
nothing #hide
````

## Simple model visualization
Before we can vizualize anything, we need to update the model so that velocities are appropriate for this particular ice thickness. We do this with the `update_state!` function:

````@example planar_one_dimensional_flow
update_state!(model)
````

Now let's plot the ice profile and ice velocity, starting with the bed

````@example planar_one_dimensional_flow
ice_plot = plot(model.grid.xxh[:,1]/1e3, model.fields.gh.b[:,1],
                linewidth = 2,
                linecolor = :brown,
                label = "bed",
                xlabel = "x (km)",
                ylabel = "z (m)");
nothing #hide
````

Now add the ice surface

````@example planar_one_dimensional_flow
plot!(ice_plot, model.grid.xxh[:,1]/1e3, model.fields.gh.s[:,1],
                linewidth = 2,
                linecolor = :blue,
                label = "ice surface");
nothing #hide
````

And finally the ice base

````@example planar_one_dimensional_flow
plot!(ice_plot, model.grid.xxh[:,1]/1e3, model.fields.gh.s[:,1] .- model.fields.gh.h[:,1],
                linewidth = 2,
                linecolor = :red,
                label = "ice base");
nothing #hide
````

We see that the ice shelf goes afloat when the ice base is approximately 270m below sea level: 270m is the product of the ratio of the densities of ice (about 900 km/m^3) and ocean (about 1000 kg/m^3) with the ice thickness (300m).

Lets also look at the velocity in the ice

````@example planar_one_dimensional_flow
vel_plot = plot(model.grid.xxh[:,1]/1e3, model.fields.gh.u[:,1],
                linewidth = 2,
                label = "ice velocity",
                xlabel = "x (km)",
                ylabel = "ice velocity (m/yr)");

p = Plots.plot(ice_plot,vel_plot, layout  = (2,1))
#display(p)
````

Ice velocities are very small (but non-zero) in the grounded ice, where friction between the ice and the bed restrains the flow. In the shelf, where there is no basal friction, velocities increase linearly to a maximum of 250 m/yr at the downstream end of the shelf.

## Running a `Simulation`

Now, let's think about advancing time. To do so, we set up a simulation, which time-steps the model forward and manages output.

A `TimesteppingParams` object controls parameters related to timestepping. Let's set the model to run for 1000 years with a timestep of 0.5 years:

````@example planar_one_dimensional_flow
timestepping_params = TimesteppingParams(dt = 0.5, end_time = 10000.);
nothing #hide
````

Now we can build the `Simulation` object and then run it!

````@example planar_one_dimensional_flow
simulation = Simulation(model = model, timestepping_params = timestepping_params);
run_simulation!(simulation);
nothing #hide
````

Our simulation ran: `simulation` holds all the information about the state at time 100 years.

## Outputting the solution
Our simulation ran successfully, but we don't have any information about what happened. We get around this by outputting the solution regularly.
First, make a clean folder where solution files will go:

````@example planar_one_dimensional_flow
folder = joinpath(@__DIR__, "planar_one_dimensional_flow");
isdir(folder) && rm(folder, force = true, recursive = true);
mkdir(folder) ;
nothing #hide
````

What and when to output is specified in WAVI.jl by an instance of an `OutputtingParams` objects. Let's set one up so that the ice thickness, (unchanging) bed, ice surface and ice velocity is output every 100 years:

````@example planar_one_dimensional_flow
output_params = OutputParams(outputs = (h = model.fields.gh.h,u = model.fields.gh.u, b = model.fields.gh.b,s = model.fields.gh.s),
                            output_freq = 1000.,
                            output_path = folder);
nothing #hide
````

Note that the `outputs` keyword argument takes a named tuple, which points to the locations of fields that are to be outputted.

Let's build a new simulation, which knows about the outputting...

````@example planar_one_dimensional_flow
simulation = Simulation(model = model, timestepping_params = timestepping_params, output_params = output_params);
nothing #hide
````

...and run it

````@example planar_one_dimensional_flow
run_simulation!(simulation);
nothing #hide
````

## Visualizing the results

Let's look at how the shape of the ice sheet changes during the simulation. To do, we'll loop over the output files and put the thickness and surface info a matrix

````@example planar_one_dimensional_flow
files = [joinpath(folder, file) for file in readdir(folder) if endswith( joinpath(folder, file), ".jld2") ] ;
nout = length(files);
h_out = zeros(simulation.model.grid.nx, nout);
surface_out = zeros(simulation.model.grid.nx, nout);
base_out = zeros(simulation.model.grid.nx, nout);
t_out = zeros(1,nout);

for i = 1:nout
    d = load(files[i]);
    h_out[:,i] = d["h"][:,1];
    base_out[:,i] = d["s"][:,1] .- d["h"][:,1];
    surface_out[:,i] = d["s"][:,1];
    t_out[i] = d["t"];
end
````

Now lets make the plot

````@example planar_one_dimensional_flow
pl = Plots.plot(simulation.model.grid.xxh[:,1], simulation.model.fields.gh.b[:,1],
                    linecolor = :brown,
                    xlabel = "x (km)",
                    ylabel = "z (m)",
                    legend = :none)
Plots.plot!(pl,simulation.model.grid.xxh[:,1], surface_out, legend = :none, linecolor = :blue)
Plots.plot!(pl,simulation.model.grid.xxh[:,1], base_out, legend = :none, linecolor = :red)
````

Finally, we clear up the files we just outputted

````@example planar_one_dimensional_flow
rm(folder, force = true, recursive = true);
nothing #hide
````

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

