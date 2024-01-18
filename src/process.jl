function proccessresults!(treemodule::TreeModule, μ, clonalmutations, rng; mutationdist=:poisson)
    return treemodule
end

function proccessresults!(population::Population{TreeModule}, μ, clonalmutations, rng; mutationdist=:poisson)
    return population
end

function processresults!(cellmodule::CellModule, μ, clonalmutations, rng::AbstractRNG;
    mutationdist=:poisson)

    mutationlist = get_mutationlist(cellmodule)
    expandedmutationids = 
        get_expandedmutationids(μ, mutationdist, mutationlist, clonalmutations, rng)
    expandmutations!(cellmodule, expandedmutationids, clonalmutations)
    
    return cellmodule
end

function processresults!(population::Population{CellModule{T}}, μ, mutationdist, 
    clonalmutations, rng::AbstractRNG) where T
    
    mutationlist = get_mutationlist(population)
    expandedmutationids = 
        get_expandedmutationids(μ, mutationdist, mutationlist, clonalmutations, rng)
    
    for cellmodule in population
        expandmutations!(cellmodule, expandedmutationids, clonalmutations)
    end
    return population
end

function final_timedep_mutations!(population::Population{CellModule{T}}, μ, mutationdist, rng;
    tend=age(population)) where T

    mutID = maximum(mutid 
        for cellmodule in population 
            for cell in cellmodule.cells
                for mutid in cell.mutations
    )

    for cellmodule in population
        mutID = final_timedep_mutations!(cellmodule, μ, mutationdist, rng; mutID, tend)
    end
end

function final_timedep_mutations!(population::SinglelevelPopulation, μ, mutationdist, rng; 
    tend = age(population))
    final_timedep_mutations!(population.singlemodule, μ, mutationdist, rng; tend)
end

function final_timedep_mutations!(cellmodule::CellModule, μ, mutationdist, rng; 
    mutID=nothing, tend=age(cellmodule))

    if isnothing(mutID)
        mutID = maximum(mutid for cell in cellmodule.cells for mutid in cell.mutations) + 1
    end
    for (μ0, mutationdist0) in zip(μ, mutationdist)
        if mutationdist0 ∈ (:poissontimedep, :fixedtimedep)
            for cell in cellmodule.cells
                Δt = tend - cell.birthtime
                numbermutations = numbernewmutations(rng, mutationdist0, μ0, Δt=Δt)
                mutID = addnewmutations!(cell, numbermutations, mutID)
            end
        end
    end
    return mutID
end

function final_timedep_mutations!(population::Population{TreeModule{T, S}}, μ, 
    mutationdist, rng; tend=age(population)) where {T <: AbstractTreeCell, S}
    
    for treemodule in population
        final_timedep_mutations!(treemodule, μ, mutationdist, rng; tend)
    end
end

function final_timedep_mutations!(treemodule::TreeModule, μ, mutationdist, rng; tend=age(treemodule))
    for (μ0, mutationdist0) in zip(μ, mutationdist)
        if mutationdist0 ∈ (:poissontimedep, :fixedtimedep)
            for cell in treemodule.cells
                Δt = tend - cell.data.birthtime
                cell.data.mutations += numbernewmutations(rng, mutationdist0, μ0, Δt=Δt)
            end
        end
    end
end

function expandmutations!(cellmodule, expandedmutationids, clonalmutations)

    if length(expandedmutationids) > 0
        for cell in cellmodule.cells
            cell.mutations = expandmutations(expandedmutationids, cell.mutations)
            if clonalmutations > 0
                prepend!(cell.mutations, 1:clonalmutations)
            end
        end
    elseif clonalmutations > 0
        for cell in cellmodule.cells
            cell.mutations = collect(1:clonalmutations)
        end
    end
    return cellmodule
end

function expandmutations(expandedmutationids, originalmutations)
    return reduce(
        vcat, 
        filter(!isempty, map(x -> expandedmutationids[x], originalmutations)),
        init=Int64[]
    )
end

function get_mutationlist(population::Population)
    #get list of all mutations assigned to each cell
    mutationlist = [mutation 
        for cellmodule in population
            for cell in cellmodule.cells
                for mutation in cell.mutations
    ]
    return sort(unique(mutationlist))
end

function get_mutationlist(cellmodule)
    #get list of all mutations assigned to each cell
    mutationlist = [mutation 
        for cell in cellmodule.cells
            for mutation in cell.mutations
    ]
    return unique(mutationlist)
end

function get_expandedmutationids(μ, mutationdist, mutationlist, clonalmutations, rng)

    mutationsN = sum(
        numberuniquemutations(rng, length(mutationlist), mutationdist0, μ0)
            for (mutationdist0, μ0) in zip(mutationdist, μ)
    )
    expandedmutationids = Dict{Int64, Vector{Int64}}()
    i = clonalmutations + 1
    for (mutkey, N) in zip(mutationlist, mutationsN)
        push!(expandedmutationids, mutkey=>collect(i:i+N-1))
        i += N
    end
    return expandedmutationids
end

function numberuniquemutations(rng, L, mutationdist, μ)
    #returns the number of unique mutations drawn from a distribution according to the
    #mutation rule with mean μ, L times.
    if mutationdist == :fixed
        return fill(μ, L)
    elseif mutationdist == :poisson
        return rand(rng, Poisson(μ), L) 
    elseif mutationdist == :geometric
        return rand(rng, Geometric(1/(1+μ)), L)
    elseif (mutationdist == :poissontimedep) || (mutationdist == :fixedtimedep)
        error("cannot add time-dependent mutations after the simulation")
    else
        error("$mutationdist is not a valid mutation rule")
    end
end

function remove_undetectable!(cellmodule, clonefreq, clonefreqp, numclones, detectableclones)
    #if there are clones outside the detectable range remove them from the data
    if sum(detectableclones) < numclones
        numclones = sum(detectableclones)
        clonefreq = clonefreq[detectableclones]
        clonefreqp = clonefreqp[detectableclones]
        cellmodule.subclones = cellmodule.subclones[detectableclones]
        pushfirst!(detectableclones, true)
        cellmodule.clonesize = cellmodule.clonesize[detectableclones]
        detectableclones = detectableclones[1:length(br)]
    end
    return cellmodule, clonefreq, clonefreqp, numclones
end


function calculateclonefreq!(clonefreq, subclonalmutations, subclones)
    for i in length(subclones):-1:2
        if subclones[i].parenttype > 1
            clonefreq[subclones[i].parenttype-1] += clonefreq[i]
            subclonalmutations[i] -= subclonalmutations[subclones[i].parenttype-1]
        end
    end
    if (sum(clonefreq.>1.0) > 0)
        error("There is a clone with frequency greater than 1, this should be impossible 
                ($(clonesize)), $(parenttype), $(clonefreq)")
    end
    return clonefreq, subclonalmutations
  end
