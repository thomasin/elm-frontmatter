module Content.Function exposing (FunctionType(..), Function, fromPath)

import Content.Internal
import Content.Output
import Path
import Parser
import Dict
import Json.Decode
import Json.Decode.Extra
import Result.Extra as Result
import String.Extra as String


-- Generating function details --


type FunctionType
    = ListItemFunction
    | SingletonFunction


type alias Function =
    { moduleDir : List String
    , name : String
    , type_ : FunctionType
    }


--type Error
--    = FileIsHidden
--    | FilePathIsEmpty
--    | FileNameIsInvalid String


--errorToOutput error =
--    case error of
--        FileIsHidden ->
--            Content.Output.Ignore [ Content.Output.Info "Ignoring hidden file" ]


fromPath : Path.Path -> Content.Output.Output Function
fromPath filePath =
    let
        cleanFilePiece : String -> Result { message : String, terminate : Bool } Content.Internal.FileName
        cleanFilePiece fullPiece =
            case Path.fromString (Path.platform filePath) fullPiece of
                Ok piecePath ->
                    if String.startsWith "." (Path.name piecePath) then
                        Ok Content.Internal.Hidden

                    else if String.startsWith "[" (Path.name piecePath) && String.endsWith "]" (Path.name piecePath) then
                        Ok (Content.Internal.Bracketed (String.classify (Path.name piecePath)))

                    else
                        Ok (Content.Internal.Normal (String.classify (Path.name piecePath)))

                Err err ->
                    Err { terminate = True, message = err }

        continuePath : List Content.Internal.FileName -> Result { message : String, terminate : Bool } { moduleDir : List String, function : Maybe ( FunctionType, String ) }
        continuePath pieces =
            case pieces of
                [] ->
                    Err
                        { terminate = False
                        , message = "Empty file path"
                        }

                file :: [] ->
                    case file of
                        Content.Internal.Hidden ->
                            Err
                                { terminate = False
                                , message = "Ignoring hidden file"
                                }

                        Content.Internal.Bracketed "Content" ->
                            Err
                                { terminate = True
                                , message = "Invalid [content].* file"
                                }

                        Content.Internal.Bracketed fileName ->
                            Ok
                                { moduleDir = []
                                , function = Just ( ListItemFunction, String.decapitalize fileName )
                                }

                        Content.Internal.Normal "Content" ->
                            Ok
                                { moduleDir = []
                                , function = Nothing
                                }

                        Content.Internal.Normal fileName ->
                            Ok
                                { moduleDir = [ fileName ]
                                , function = Just ( SingletonFunction, "content" )
                                }

                folder :: restPath ->
                    let
                        fillInModuleDir : String -> { moduleDir : List String, function : Maybe ( FunctionType, String ) } -> { moduleDir : List String, function : Maybe ( FunctionType, String ) }
                        fillInModuleDir moduleName details =
                            { details | moduleDir = moduleName :: details.moduleDir }

                        fillInFunction : ( FunctionType, String ) -> { moduleDir : List String, function : Maybe ( FunctionType, String ) } -> { moduleDir : List String, function : Maybe ( FunctionType, String ) }
                        fillInFunction function details =
                            case details.function of
                                Just _ ->
                                    details

                                Nothing ->
                                    { details | function = Just function }
                    in
                    case folder of
                        Content.Internal.Hidden ->
                            Err
                                { terminate = False
                                , message = "Ignoring hidden folder"
                                }

                        Content.Internal.Bracketed "Content" ->
                            Err
                                { terminate = True
                                , message = "Invalid [content] folder"
                                }

                        Content.Internal.Normal "Content" ->
                            Err
                                { terminate = True
                                , message = "Invalid content folder"
                                }

                        Content.Internal.Bracketed folderName ->
                            continuePath restPath
                                |> Result.map (fillInFunction ( ListItemFunction, String.decapitalize folderName))

                        Content.Internal.Normal folderName ->
                            continuePath restPath
                                |> Result.map (fillInModuleDir (String.classify folderName))
                                |> Result.map (fillInFunction ( SingletonFunction, "content" ))
    in
    case Result.andThen continuePath (Result.combine (List.map cleanFilePiece (Path.toList filePath))) of
        Ok details ->
            case details.function of
                Nothing ->
                    Content.Output.Terminate "Invalid top-level content.* file"

                Just ( functionType, functionName ) ->
                    case details.moduleDir of
                        [] ->
                            Content.Output.Terminate ("Invalid top-level [*].* file: " ++ Path.toString filePath)

                        _ ->
                            Content.Output.Continue []
                                { moduleDir = "Content" :: details.moduleDir
                                , name = functionName
                                , type_ = functionType
                                }

        Err err ->
            if err.terminate then
                Content.Output.Terminate err.message

            else
                Content.Output.Ignore [ Content.Output.Info err.message ]
