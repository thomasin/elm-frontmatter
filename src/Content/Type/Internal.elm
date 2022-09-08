module Content.Type.Internal exposing (fromFunctionType)

import Content.Function
import Content.Type


fromFunctionType : Content.Function.FunctionType -> List String -> Content.Type.Path
fromFunctionType functionType moduleDir =
    case functionType of
        Content.Function.SingletonFunction ->
            Content.Type.Single moduleDir

        Content.Function.CollectionItemFunction ->
            Content.Type.Collection moduleDir
