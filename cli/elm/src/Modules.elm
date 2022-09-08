module Modules exposing (Contents, InputFile, modulesToList, newFunction)

import Content.Function
import Content.Module
import Dict
import Json.Decode
import Path


type alias InputFile =
    { filePath : Path.Path
    , fileFrontmatter : Json.Decode.Value
    }


type alias Contents =
    Dict.Dict (List String) (Dict.Dict String Content.Module.UndecodedFunction)


modulesToList : Contents -> List Content.Module.UndecodedModule
modulesToList filesDict =
    Dict.toList filesDict
        |> List.map
            (\( moduleDir, functions ) ->
                { dir = moduleDir
                , functions = functions
                }
            )


newFunction : Content.Function.Function -> InputFile -> Contents -> Contents
newFunction function inputDetails modules =
    Dict.update function.moduleDir
        (\maybeExistingDetails ->
            case maybeExistingDetails of
                Just existingDetails ->
                    Just (Dict.insert function.name { type_ = function.type_, inputFilePath = inputDetails.filePath, frontmatter = inputDetails.fileFrontmatter } existingDetails)

                Nothing ->
                    Just (Dict.singleton function.name { type_ = function.type_, inputFilePath = inputDetails.filePath, frontmatter = inputDetails.fileFrontmatter })
        )
        modules
