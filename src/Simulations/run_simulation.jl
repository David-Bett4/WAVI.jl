"""
    timestep!(simulation)

Perform one timestep of the simulation
"""
function timestep!(simulation)
    @unpack model,timestepping_params = simulation
    update_state!(model)
    if timestepping_params.step_thickness
        update_thickness!(simulation)
    end
    update_clock!(simulation)
end

"""
update_thickness!(model::AbstractModel)

Update thickness using rate of change of thickness and apply minimum thickness constraint.
"""
function update_thickness!(simulation::AbstractSimulation)
@unpack model,timestepping_params=simulation
onesvec=ones(model.grid.nx*model.grid.ny)
model.fields.gh.h[model.fields.gh.mask] = model.fields.gh.h[model.fields.gh.mask] .+ max.(model.params.minimum_thickness .- model.fields.gh.h[model.fields.gh.mask],timestepping_params.dt*model.fields.gh.dhdt[model.fields.gh.mask])
return simulation
end

"""
    update_clock!(simulation::AbstractSimulation)

Update the simulation clock
"""
function update_clock!(simulation::AbstractSimulation)
    @unpack clock,timestepping_params=simulation
    clock.n_iter += 1
    clock.time += timestepping_params.dt
    return simulation
end


"""
    run_simulation(simulation)
Perform the simulation specified by the simulation
"""
function run_simulation!(simulation::Simulation)
    @unpack model, timestepping_params, output_params = simulation
    chkpt_tag = "A"
    if model.grid.Cxl > 1
       u_out_line = zeros[model.grid.Cxl-1,model.grid.Cyl:model.grid.Cyu] 
       h_out_line = zeros[model.grid.Cxl-1,model.grid.Cyl:model.grid.Cyu] 
    end
    for i = (simulation.clock.n_iter+1):timestepping_params.n_iter_total
        timestep!(simulation)

        if model.grid.Cxl > 1
         u_out_line = u_out_line + model.fields.gh.u[model.grid.Cxl-1,model.grid.Cyl:model.grid.Cyu]
         h_out_line = h_out_line + model.fields.gh.h[model.grid.Cxl-1,model.grid.Cyl:model.grid.Cyu]
          if (i == timestepping_params.n_iter_total)
          u_out_line= u_out_line ./ (timestepping_params.n_iter_total- simulation.clock.n_iter)
          h_out_line= h_out_line ./ (timestepping_params.n_iter_total- simulation.clock.n_iter)
          end
        end
        
        #check if we have hit a temporary checkpoint
        if mod(i,timestepping_params.n_iter_chkpt) == 0
            #output a temporary checkpoint
            fname = string("Chkpt",chkpt_tag, ".jld2")
            @save fname simulation
            chkpt_tag = (chkpt_tag == "A") ? "B" : "A"
            println("making temporary checkpoint at timestep number $(simulation.clock.n_iter)")
        end

        #check if we have hit a permanent checkpoint
        if mod(i,simulation.timestepping_params.n_iter_pchkpt) == 0
            #output a permanent checkpoint
            n_iter_string =  lpad(simulation.clock.n_iter, 10, "0"); #filename as a string with 10 digits
            fname = string("PChkpt_",n_iter_string, ".jld2")
            @save fname simulation
            println("making permanent checkpoint at timestep number $(simulation.clock.n_iter)")
        end

        #check if we have hit an output timestep
        if mod(i,simulation.output_params.n_iter_out) == 0
            write_output(simulation)
            println("outputting at timestep number $(simulation.clock.n_iter)")

        end

        #check the dump velocity flag at the final timestep
        if (i == timestepping_params.n_iter_total) && output_params.dump_vel
            write_vel(simulation)
        end
    end

    #zip the simulation output (no zipping handled by zip_output)
    zip_output(simulation)
        
    return simulation
end

"""
    function write_vel(simulation)

Write the velocity at the the final timestep of the simulation (used in the coupled wavi-mitgcm model to communicate with streamice)
"""
function write_vel(simulation::Simulation)
    @unpack model = simulation  
    uVel_file_string = string(simulation.output_params.prefix,  "_U.bin")
    vVel_file_string = string(simulation.output_params.prefix,  "_V.bin")
    
    u_out = zeros(model.grid.Cxu - model.grid.Cxl + 1 + 1,model.grid.Cyu - model.grid.Cyl +1)
    v_out = zeros(model.grid.Cxu - model.grid.Cxl + 1 + 1,model.grid.Cyu - model.grid.Cyl +1)
    
    u_out[2:end,:]=model.fields.gu.u[model.grid.Cxl:model.grid.Cxu,model.grid.Cyl:model.grid.Cyu]
    v_out[2:end,:]=model.fields.gv.v[model.grid.Cxl:model.grid.Cxu,model.grid.Cyl:model.grid.Cyu]

    u_out .= hton.(u_out)
    v_out .= hton.(v_out)

    ufileID =  open(uVel_file_string,"w")
      write(ufileID, u_out[:,:])
    close(ufileID) 
    vfileID =  open(vVel_file_string,"w")
    write(vfileID, v_out[:,:])
    close(vfileID)   
    
    if model.grid.Cxl > 1
    
     #u_out_line = model.fields.gh.u[model.grid.Cxl-1,model.grid.Cyl:model.grid.Cyu]
     #h_out_line = model.fields.gh.h[model.grid.Cxl-1,model.grid.Cyl:model.grid.Cyu]
     #h_out_line = h_out_b[:]
     
     h_out_b = zeros(model.grid.Cxu - model.grid.Cxl + 1 + 1,model.grid.Cyu - model.grid.Cyl +1)
     u_out_b = zeros(model.grid.Cxu - model.grid.Cxl + 1 + 1,model.grid.Cyu - model.grid.Cyl +1)  
     
     h_out_b[2,:] .= h_out_line[:]
     u_out_b[2,:] .= u_out_line[:]  
        
     h_out_b .= hton.(h_out_b)
     u_out_b .= hton.(u_out_b)
    
     hb_file_string = string(simulation.output_params.prefix,  "_Hb.bin")
     ub_file_string = string(simulation.output_params.prefix,  "_Ub.bin")
    
     hbfileID =  open(hb_file_string,"w")
     write(hbfileID, h_out_b[:,:])
     close(hbfileID) 
        
     ubfileID =  open(ub_file_string,"w")
     write(ubfileID, u_out_b[:,:])
     close(ubfileID)
    
    end
 end 
