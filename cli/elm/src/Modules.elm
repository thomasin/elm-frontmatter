module Modules exposing (..)


import Content.Function
import Content.Decode.File
import Path
import Parser
import Dict
import Json.Decode
import Json.Decode.Extra
import Result.Extra as Result
import String.Extra as String


type alias Contents =
    Dict.Dict (List String) (Dict.Dict String { type_ : Content.Function.FunctionType, inputFile : Content.Decode.File.InputFile })



--toDict : FileDetails -> Dict.Dict String Content.Decode.File.InputFile
--toDict fileDetails =
--    case fileDetails of
--        JustContent ( functionName, inputFile ) ->
--            Dict.singleton functionName inputFile

--        JustListItems functionDict ->
--            functionDict

--        Both ( functionName, inputFile ) functionDict ->
--            Dict.insert functionName inputFile functionDict


--type ModuleContent
--    = JustContent ( String, Content.Decode.File.InputFile )
--    | JustListItems (Dict.Dict String Content.Decode.File.InputFile)
--    | Both ( String, Content.Decode.File.InputFile ) (Dict.Dict String Content.Decode.File.InputFile)

modulesToList : Contents -> List Content.Decode.File.OutputModule
modulesToList filesDict =
    Dict.toList filesDict
        |> List.map
            (\( moduleDir, functions ) ->
                { dir = moduleDir
                , functions = functions
                }
            )


newFunction : Content.Function.Function -> Content.Decode.File.InputFile -> Contents -> Contents
newFunction function inputDetails modules =
    Dict.update function.moduleDir
        (\maybeExistingDetails ->
            case maybeExistingDetails of
                Just existingDetails ->
                    Just (Dict.insert function.name { type_ = function.type_, inputFile = inputDetails } existingDetails)
                    --Just
                    --    (case ( existingDetails, function.type_ ) of
                    --        ( JustContent content, Content.File.SingletonFunction ) ->
                    --            JustContent content

                    --        ( JustContent content, Content.File.ListItemFunction ) ->
                    --            Both content (Dict.singleton function.name inputDetails)

                    --        ( JustListItems listItems, Content.File.SingletonFunction ) ->
                    --            Both ( function.name, inputDetails ) listItems

                    --        ( JustListItems listItems, Content.File.ListItemFunction ) ->
                    --            JustListItems (Dict.union listItems (Dict.singleton function.name inputDetails))

                    --        ( Both content listItems, Content.File.SingletonFunction ) ->
                    --            Both content listItems

                    --        ( Both content listItems, Content.File.ListItemFunction ) ->
                    --            Both content (Dict.union listItems (Dict.singleton function.name inputDetails))
                    --    )

                Nothing ->
                    Just (Dict.singleton function.name { type_ = function.type_, inputFile = inputDetails })
                    --case function.type_ of
                    --    Content.File.SingletonFunction ->
                    --        Just (JustContent ( function.name, inputDetails ))

                    --    Content.File.ListItemFunction ->
                    --        Just (JustListItems (Dict.singleton function.name inputDetails))
        ) modules
