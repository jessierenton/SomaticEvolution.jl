function getVAFresult(simulation::Simulation, rng::AbstractRNG=Random.GLOBAL_RNG; read_depth=100.0, 
    detectionlimit=5/read_depth, cellularity=1.0)

    trueVAF = getallelefreq(simulation)
    sampledVAF = sampledallelefreq(trueVAF, rng, read_depth=read_depth, 
        detectionlimit=detectionlimit, cellularity=cellularity)
    freq, freqp = subclonefreq(simulation.output)

    return VAFResult(
        read_depth,
        cellularity,
        detectionlimit,
        simulation.input,
        trueVAF,
        sampledVAF,
        freq,
        freqp
    )
end

function getVAFresult(multisim::MultiSimulation, rng::AbstractRNG=Random.GLOBAL_RNG; read_depth=100.0, 
    detectionlimit=5/read_depth, cellularity=1.0)

    trueVAFs = Vector{Float64}[]
    sampledVAFs = Vector{Float64}[]
    freqs = Vector{Float64}[]
    freqps = Vector{Float64}[]
    
    for cellmodule in multisim
        trueVAF = getallelefreq(cellmodule)
        sampledVAF = sampledallelefreq(trueVAF, rng, read_depth=read_depth, 
            detectionlimit=detectionlimit, cellularity=cellularity)
        freq, freqp = subclonefreq(cellmodule)
        push!(trueVAFs, trueVAF)
        push!(sampledVAFs, sampledVAF)
        push!(freqs, freq)
        push!(freqps, freqp)
    end

    return VAFResultMulti(
        read_depth,
        cellularity,
        detectionlimit,
        simulation.input,
        trueVAFs,
        sampledVAFs,
        freqs,
        freqps
    )
end

function getallelefreq(simulation::Simulation)
    return getallelefreq(simulation.output, simulation.input.ploidy)
end

function getallelefreq(cellmodule::CellModule, ploidy)
    mutations = cellsconvert(cellmodule.cells).mutations
    return getallelefreq(mutations, cellmodule.Nvec[end], ploidy)
end

function getallelefreq(cellmodules::Vector{CellModule}, ploidy)
    mutations, clonetype = cellsconvert([cell for cellmodule in cellmodules for cell in cellmodule.cells])
    N = length(clonetype)
    return getallelefreq(mutations, N, ploidy)
end

function getallelefreq(population::Union{MultiSimulation{S, T}, Vector{T}}, ploidy) where {S, T <: CellModule}
    return getallelefreq(population.output, ploidy)
end

function getallelefreq(mutations, N, ploidy=2)
    allelefreq = Float64.(counts(mutations, 1:N))
    # idx = f .> 0.01 #should this be f/(2*cellnum) .> 0.01, i.e. only include freq > 1% ??
    allelefreq ./= (ploidy * N) #correct for ploidy
end

function getfixedallelefreq(mutations::Vector{Int64})
    return counts(mutations)    
end

function getfixedallelefreq(population::Union{MultiSimulation{S, T}, Vector{T}}, 
    idx=nothing) where {S, T <: CellModule}
    mutations = reduce(vcat, clonal_mutation_ids(population, idx))
    return getfixedallelefreq(mutations)
end

function cellsconvert(cells)
    #convert from array of cell types to one array with mutations and one array with cell fitness

    clonetype = zeros(Int64,length(cells))
    mutations = Int64[]
    # sizehint!(mutations, length(cells) * 10) #helps with performance to provide vector size

    for i in 1:length(cells)
        append!(mutations,cells[i].mutations)
        clonetype[i] = cells[i].clonetype
    end

    return (;mutations, clonetype)
end

"""
    sampledhist(trueVAF::Vector{Float64}, cellnum::Int64; <keyword arguments>)

Create synthetic experimental data by smapling from the true VAF distribution 
according to experimental constraints. 

### Keyword arguments
- `detectionlimit = 5/read_depth`: minimum VAF which can be detected
- `read_depth = 100`: expected number of reads for each allele
- `cellularity = 1.0`: 

"""
function sampledallelefreq(trueVAF::Vector{Float64}, rng::AbstractRNG; 
    read_depth=100.0, detectionlimit=5/read_depth, cellularity=1.0)

    VAF = trueVAF * cellularity
    filter!(x -> x > detectionlimit, VAF)
    # Pois(np) ≈ B(n,p) when n >> p, thus we can sample from Poisson(read_depth)
    # rather than Binomial(cellnum, read_depth/cellnum), length(VAF)) as D << N^2
    depth = rand(rng, Poisson(read_depth), length(VAF))
    sampalleles = map((n, p) -> rand(rng, Binomial(n, p)), depth, VAF)
    sampledVAF = sampalleles ./ depth
    return sampledVAF
end

"""
    gethist(VAF::Vector{Float64}; fmin = 0.0, fmax = 1.0, fstep = 0.001)

Fit VAF data into bins `fmin`:`fstep`:`fmax` and return DataFrame with columns
:VAF, :freq [= ``m(f)``], :cumfreq [= ``M(f)``].

Note ``M(f)`` is the cummulative number of mutations with frequency ``f``, i.e. the 
number of mutations with frequency in ``(f, 1)``, while ``m(f)`` is the number of mutations with 
frequency in ``(f - fstep, f)``.

"""
function gethist(VAF::Vector{Float64}; fmin = 0.0, fmax = 1, fstep = 0.001)
    x = fmin:fstep:fmax
    y = fit(Histogram, VAF, x, closed=:right).weights
    dfhist = DataFrame(VAF = x[2:end], freq = y)
    dfhist = addcumfreq!(dfhist,:freq)
    return dfhist
end


function addcumfreq!(df,colname)
    df[!, Symbol(:cum,colname)] = reverse(cumsum(reverse(df[!, colname])))
    return df
end

function subclonefreq(cellmodule)
    #get proportion of cells in each subclone
    clonesize = getclonesize(cellmodule)
    clonefreqp = clonesize[2:end]/sum(clonesize)
    clonefreq = copy(clonefreqp)
    if length(clonefreqp) > 1
        clonefreq, subclonalmutations = 
            calculateclonefreq!(clonefreq, subclonalmutations, cellmodule.subclones)
    end
    return clonefreq, clonefreqp
end