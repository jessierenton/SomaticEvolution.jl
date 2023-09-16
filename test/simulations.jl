@testset "neutral runsimulation" begin
    rng = MersenneTwister(100)
    input = BranchingInput(
        Nmax=10, 
        mutationdist=:poisson, 
        birthrate=1, 
        deathrate=0.0,
        clonalmutations=0, 
        numclones=0,
        μ=1
    )
    simulation = runsimulation(input, rng)
    @test length(simulation.output) == 10

    tmax=10
    input = MoranInput(
        N=10, 
        tmax=tmax,
        mutationdist=:poisson, 
        moranrate=1.0,
        clonalmutations=0, 
        numclones=0,
        μ=1
    )
    simulation = runsimulation(input, rng)
    @test all(length(simulation.output) .== 10)
    @test simulation.output.t <=tmax
    tmax=10
    input = BranchingMoranInput(
        Nmax=10, 
        tmax=tmax,
        mutationdist=:poisson, 
        birthrate=1, 
        deathrate=0.0,
        clonalmutations=0, 
        numclones=0,
        μ=1
    )
    simulation = runsimulation(input, rng)
    @test length(simulation.output) == 10
    @test simulation.output.t <= tmax
end

@testset "cell transitions" begin
    
end

#check birth and death rates are calculated correctly
birthrate, deathrate, mutant_selection = 1, 0, [1, 2]
birthrates, deathrates = SomaticEvolution.set_branching_birthdeath_rates(birthrate, deathrate, mutant_selection) 
@test birthrates == [1, 2, 3]
@test deathrates == [0, 0, 0]