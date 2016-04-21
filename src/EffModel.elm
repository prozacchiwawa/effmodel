module EffModel (
        EffModel
    ,   get
    ,   wrap
    ,   wrap2
    ,   unwrap
    ,   map
    ,   eff
    ,   effMap
    ,   effMessage)
    where

{-|

EffModel embodies a single value that carries both the model and accumulated
effects for a world step in the elm architecture.

The elm architecture is nice, but a tuple of model and effect is troublesome
to compose.  Consider the standard update function:

update : Action -> Model -> (Model, Effects Action)

In order to compose it, you need to destructure the result, use Effects.batch
on the snd, and map on the first, then combine a new tuple.  EffModel replaces
this process and has functions that construct an effmodel either from a model
or an update result tuple, and that produce an update result tuple from an
EffModel.

I use it extensively like this:

import EffModel as EF

handleUpdateForOneLogicalThing : Action -> EffModel Model Action -> EffModel Model Action
handleUpdateForOneLogicalThing action effmodel =
    case action of
        Increment -> effmodel |> EF.map (\m -> { m | count = m.count + 1 })
        Decrement ->
            effmodel
                -- Compose model update and an effect conveniently
                |> EF.map (\m -> { m | count = m.count - 1 })
                |> EF.eff (Effects.task (Task.sleep (5 * Time.second) `Task.andThen` (\_ -> Task.succeed Increment)))
        _ -> effmodel -- Note that you can just pass it through easily

handleUpdateForAnotherLogicalThing : Action -> EffModel Model Action -> EffModel Model Action

update : Action -> Model -> (Model, Effects Action)
update action model =
    model
        |> wrap
        |> handleUpdateForOneLogicalThing action
        |> handleUpdateForAnotherLogicalThing action
        |> unwrap

# Definition

@docs EffModel

# Creation functions

@docs wrap, wrap2

# Termination

@docs unwrap

# Accessor

@docs get

# Operations

@docs map, eff, effMap, effMessage

-}

import Effects exposing (Effects(..), none, batch, tick)
import Task

{-|

A type representing the combination of a model value and the accumulated
effects of a chain of composed actions on a model along with emitted
effects.

-}
type alias EffModel model action = {
        model : model
    ,   eff : Effects action
    }

{-|

Get the model from an EffModel:

case action of
    IncrementAndNotify ->
        effmodel
            |> (\effmodel -> EF.effMessage (Notify (EF.get m).count) effmodel)

-}
get : EffModel model action -> model
get effmodel = effmodel.model

{-|

Wrap a model to start an EffModel chain.

-}
wrap : model -> EffModel model action
wrap model = {
        model = model
    ,   eff = Effects.none
    }

{-|

Wrap a model and previous effects (such as the result from an update) in an
EffModel.

-}
wrap2 : (model, Effects action) -> EffModel model action
wrap2 (model, effects) = {
        model = model
    ,   eff = effects
    }

{-|

Terminate a chain of EffModel updates to yield Tuple of model, effects.

-}
unwrap : EffModel model action -> (model, Effects action)
unwrap effmodel =
    (effmodel.model, effmodel.eff)

{-|

Update the model in the EffModel.

-}
map : (modelA -> modelB) -> EffModel modelA action -> EffModel modelB action
map f effmodel =
    { model = f effmodel.model, eff = effmodel.eff }

{-|

Add an effect to the EffModel's accumulated effects.

-}
eff : Effects action -> EffModel model action -> EffModel model action
eff eff effmodel =
    { model = effmodel.model, eff = batch [effmodel.eff, eff] }

{-|

Apply Effects.map to the accumulated effects.

-}
effMap : (actionA -> actionB) -> EffModel model actionA -> EffModel model actionB
effMap f effmodel =
    { effmodel | eff = Effects.map f effmodel.eff }

{-|

Convenience replacement for (Effects.task (Task.succeed action)) that can be used
place another message on the app's input queue.

-}
effMessage : action -> EffModel model action -> EffModel model action
effMessage action effmodel =
    effmodel |> eff (Effects.task (Task.succeed action))
