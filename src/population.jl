abstract type AbstractPopulation end
abstract type MultilevelPopulation <: AbstractPopulation end

struct Population{T<:AbstractModule} <: MultilevelPopulation
    homeostatic_modules::Vector{T}
    growing_modules::Vector{T}
    subclones::Vector{Subclone}
end

struct PopulationWithQuiescence{T<:AbstractModule} <: MultilevelPopulation
    homeostatic_modules::Vector{T}
    quiescent_modules::Vector{T}
    growing_modules::Vector{T}
    subclones::Vector{Subclone}
end

struct SinglelevelPopulation{T<:AbstractModule} <: AbstractPopulation
    singlemodule::T
    subclones::Vector{Subclone}
end

Base.size(population::SinglelevelPopulation) = (length(population),)

function Base.size(population::Population)
    return (length(population.homeostatic_modules), length(population.growing_modules))
end

function Base.size(population::PopulationWithQuiescence)
    return (
        length(population.homeostatic_modules),
        length(population.quiescent_modules),
        length(population.growing_modules)
    )
end


Base.length(population::SinglelevelPopulation) = length(population.singlemodule)

function Base.length(population::Population)
    return length(population.homeostatic_modules) + length(population.growing_modules)
end

function Base.length(population::PopulationWithQuiescence)
    return length(population.homeostatic_modules) +
        length(population.quiescent_modules) +
        length(population.growing_modules)
end

function Base.iterate(population::Population)
    return iterate(
        Base.Iterators.flatten((population.homeostatic_modules, population.growing_modules))
    )
end

function Base.iterate(population::Population, state)
    return iterate(
        Base.Iterators.flatten(
            (population.homeostatic_modules, population.growing_modules)
        ),
        state
    )
end

function Base.iterate(population::PopulationWithQuiescence)
    return iterate(
        Base.Iterators.flatten((
            population.homeostatic_modules,
            population.quiescent_modules,
            population.growing_modules
        ))
    )
end

function Base.iterate(population::PopulationWithQuiescence, state)
    return iterate(
        Base.Iterators.flatten((
            population.homeostatic_modules,
            population.quiescent_modules,
            population.growing_modules
        )),
        state
    )
end

function Base.getindex(population::Population, i)
    Nhom = length(population.homeostatic_modules)
    if i <= Nhom
        return Base.getindex(population.homeostatic_modules, i)
    else
        return Base.getindex(population.growing_modules, i - Nhom)
    end
end

function Base.getindex(population::PopulationWithQuiescence, i)
    Nhom = length(population.homeostatic_modules)
    Nqui = length(population.quiescent_modules)
    if i <= Nhom
        return Base.getindex(population.homeostatic_modules, i)
    elseif i <= Nhom + Nqui
        return Base.getindex(population.quiescent_modules, i - Nhom)
    else
        return Base.getindex(population.growing_modules, i - Nhom - Nqui)
    end
end

function Base.getindex(population::Population, a::Vector{Int64})
    return map(i -> getindex(population, i), a)
end

function Base.getindex(population::PopulationWithQuiescence, a::Vector{Int64})
    return map(i -> getindex(population, i), a)
end

function Base.setindex(population::Population, v, i)
    Nhom = length(population.homeostatic_modules)
    if i <= Nhom
        return Base.setindex(population.homeostatic_modules, v, i)
    else
        return Base.setindex(population.growing_modules, v, i - Nhom)
    end
end

function Base.setindex(population::PopulationWithQuiescence, v, i)
    Nhom = length(population.homeostatic_modules)
    Nqui = length(population.quiescent_modules)
    if i <= Nhom
        return Base.setindex(population.homeostatic_modules, v, i)
    elseif i <= Nhom + Nqui
        return Base.setindex(population.quiescent_modules, v, i - Nhom)
    else
        return Base.setindex(population.growing_modules, v, i - Nhom - Nqui)
    end
end

function Base.firstindex(population::Population)
    if length(population.homeostatic_modules) != 0
        return firstindex(population.homeostatic_modules)
    else
        return firstindex(population.growing_modules)
    end
end

function Base.firstindex(population::PopulationWithQuiescence)
    if length(population.homeostatic_modules) != 0
        return firstindex(population.homeostatic_modules)
    elseif length(population.quiescent_modules) != 0
        return firstindex(population.quiescent_modules)
    else
        return firstindex(population.growing_modules)
    end
end

function Base.lastindex(population::Population)
    if length(population.growing_modules) != 0
        return lastindex(population.growing_modules)
    else
        return lastindex(population.homeostatic_modules)
    end
end

function Base.lastindex(population::PopulationWithQuiescence)
    if length(population.growing_modules) != 0
        return lastindex(population.growing_modules)
    elseif length(population.quiescent_modules) != 0
        return lastindex(population.quiescent_modules)
    else
        return lastindex(population.homeostatic_modules)
    end
end

function Population(
    homeostatic_modules::Vector{T},
    growing_modules::Vector{T},
    birthrate,
    deathrate,
    moranrate,
    asymmetricrate
) where T
    return Population{T}(
        homeostatic_modules,
        growing_modules,
        Subclone[Subclone(
            1,
            0,
            0.0,
            sum(length.(homeostatic_modules)) + sum(length.(growing_modules)),
            birthrate,
            deathrate,
            moranrate,
            asymmetricrate
        )]
    )
end

function PopulationWithQuiescence(
    homeostatic_modules::Vector{T},
    quiescent_modules::Vector{T},
    growing_modules::Vector{T},
    birthrate,
    deathrate,
    moranrate,
    asymmetricrate
) where T
    return PopulationWithQuiescence{T}(
        homeostatic_modules,
        quiescent_modules,
        growing_modules,
        Subclone[Subclone(
            1,
            0,
            0.0,
            sum(length.(homeostatic_modules)) + sum(length.(growing_modules)),
            birthrate,
            deathrate,
            moranrate,
            asymmetricrate
        )]
    )
end

function SinglelevelPopulation(
    singlemodule::T,
    birthrate,
    deathrate,
    moranrate,
    asymmetricrate
) where T
    return SinglelevelPopulation{T}(
        singlemodule,
        Subclone[Subclone(
            1,
            0,
            0.0,
            length(singlemodule),
            birthrate,
            deathrate,
            moranrate,
            asymmetricrate
        )]
    )
end

allmodules(population) = vcat(population.homeostatic_modules, population.growing_modules)

function number_cells_by_subclone(modules, nsubclones)
    ncells = zeros(Int64, nsubclones)
    for mod in modules
        for cell in mod.cells
            ncells[getclonetype(cell)] += 1
        end
    end
    return ncells
end

function number_cells_in_subclone(modules, subcloneid)
    return sum(getclonetype(cell) == subcloneid for mod in modules for cell in mod.cells)
end

function Base.show(io::IO, population::Population{T}) where T
    Base.show(io, Population{T})
    @printf(io, ": \n    %d growing modules", length(population.growing_modules))
    @printf(io, "\n    %d homeostatic modules", length(population.homeostatic_modules))
    @printf(io, "\n    %d subclones", length(filter(x -> x.size > 0, population.subclones)))
end

function Base.show(io::IO, population::PopulationWithQuiescence{T}) where T
    Base.show(io, Population{T})
    @printf(io, ": \n    %d growing modules", length(population.growing_modules))
    @printf(io, "\n    %d homeostatic modules", length(population.homeostatic_modules))
    @printf(io, "\n    %d quiescent modules", length(population.quiescent_modules))
    @printf(io, "\n    %d subclones", length(filter(x -> x.size > 0, population.subclones)))
end

function Base.show(io::IO, population::SinglelevelPopulation{T}) where T
    Base.show(io, SinglelevelPopulation{T})
    mod = population.singlemodule
    @printf(io, ": \n    %d cells ", length(mod))
    printmodule(io, mod)
    @printf(io, " (t = %.2f)", age(mod))
end

function Base.show(io::IO, mod::T) where T<:AbstractModule
    Base.show(io, T)
    @printf(io, ": \n    %d cells ", length(mod))
    printmodule(io, mod)
    @printf(io, " (t = %.2f)", age(mod))


end

function printmodule(io::IO, mod::AbstractModule; maxsubclone=nothing)
    if length(mod) == 0
        @printf(io, "[]")
    else
        subclonelist = sort!([getclonetype(cell) for cell in mod])
        unique_subclones = unique(subclonelist)
        @printf(io, "[")
        if length(unique_subclones) == 1
            @printf(io, "%d (%d)", length(subclonelist), unique_subclones[1])
        else
            for subcloneid in unique_subclones[1:end-1]
                @printf(io, "%d (%d), ", count(x->x==subcloneid, subclonelist), subcloneid)
            end
            subcloneid = unique_subclones[end]
            @printf(io, "%d (%d)", count(x->x==subcloneid, subclonelist), subcloneid)
        end
        @printf(io, "]")
    end
end
