using Test, WAVI, LinearAlgebra
@testset  "WAVI tests" begin
    @testset "Iceberg" begin
        include("verification_tests/iceberg_test.jl")
        sim=iceberg_test(end_time = 1000.)
        #Steady state iceberg thickness and velocity
        #a = 0.3 m/yr, A=2.0e-17 Pa^-3 a^-1
        #ice density 918 kg/m3 ocean density 1028.0 kg/m3, Glen law n=3.
        h0=((36.0*0.3/(2.0e-17))*(1.0/(9.81*918.0*(1-918.0/1028.0)))^3)^(1.0/4.0)
        u0=sim.model.grid.xxu*0.3/(2.0*h0)
        v0=sim.model.grid.yyv*0.3/(2.0*h0)
        relerr_h=norm(sim.model.fields.gh.h[sim.model.fields.gh.mask].-h0)/
                    norm(h0*ones(length(sim.model.fields.gh.h[sim.model.fields.gh.mask])))
        relerr_u=norm(sim.model.fields.gu.u[sim.model.fields.gu.mask]-u0[sim.model.fields.gu.mask])/
                         norm(u0[sim.model.fields.gu.mask])
        relerr_v=norm(sim.model.fields.gv.v[sim.model.fields.gv.mask]-v0[sim.model.fields.gv.mask])/
                         norm(v0[sim.model.fields.gv.mask])
        @test relerr_h < 1.0e-4
        @test relerr_u < 3.0e-4
        @test relerr_v < 3.0e-4
    end

end
if true 
@testset "MISMIP+ verification experiments" begin 
    @testset "MISMIP+ Ice0 verification experiments" begin
        @info "Performing MISMIP+ Ice0 verification experiments"
        include(joinpath("verification_tests","MISMIP_PLUS_Ice0.jl"))
        simulation=MISMIP_PLUS_Ice0()
        glx=WAVI.get_glx(simulation.model)
        glxtest=glx[[1,div(simulation.model.grid.ny,2),div(simulation.model.grid.ny,2)+1,simulation.model.grid.ny]]
        @test length(glx) == simulation.model.grid.ny #check that the grounding line covers the whole domain in the y-direction
        @test (glxtest[4]-glxtest[1])/(glxtest[4]+glxtest[1]) < 1e-4
        @test (glxtest[2]-glxtest[3])/(glxtest[2]+glxtest[3]) < 1e-4
        @test 480000<glxtest[1]<540000
        @test 480000<glxtest[4]<540000
        @test 430000<glxtest[2]<460000
        @test 430000<glxtest[3]<460000

        #check the melt rate for ice_1r is doing something sensible
        function m1(h, b)
            draft = -(918.0 / 1028.0) * h
            cavity_thickness = draft .- b
            cavity_thickness = max.(cavity_thickness, 0)
            m =  0.2*tanh.(cavity_thickness./75).*max.((-100 .- draft), 0)
            return m
        end
        melt = m1.(simulation.model.fields.gh.h, simulation.model.fields.gh.h)
        @test all(melt .>= 0)
        @test maximum(melt) < 100

    end
end
end