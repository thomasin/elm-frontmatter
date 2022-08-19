module Content.File exposing (FileContent(..), FileDetails, FileType(..), Files, Frontmatter, InputFile, decodeInputFile, filesToList, newFile, outputPath)

import Content.Internal
import Content.Path
import Dict
import Json.Decode
import Json.Decode.Extra
import Result.Extra as Result
import String.Extra as String


type alias InputFile =
    { filePath : Content.Path.Path
    , fileFrontmatter : Frontmatter
    }


type alias Frontmatter =
    Json.Decode.Value


decodeInputFile : Json.Decode.Decoder InputFile
decodeInputFile =
    Json.Decode.map2 InputFile
        (Json.Decode.field "filePath"
            (Json.Decode.string
                |> Json.Decode.andThen
                    (Json.Decode.Extra.fromResult << Content.Path.parse)
            )
        )
        (Json.Decode.field "fileFrontmatter" Json.Decode.value)



-- Frontmatter --


type FileContent
    = JustContent ( String, InputFile )
    | JustListItems (Dict.Dict String InputFile)
    | Both ( String, InputFile ) (Dict.Dict String InputFile)


type alias FileDetails =
    { moduleDir : List String
    , content : FileContent
    }


type alias Files =
    Dict.Dict (List String) FileContent


filesToList : Files -> List FileDetails
filesToList filesDict =
    Dict.toList filesDict
        |> List.map
            (\( moduleDir, content ) ->
                { moduleDir = moduleDir
                , content = content
                }
            )


newFile : OutputDetails -> InputFile -> Files -> Files
newFile outputDetails inputDetails files =
    Dict.update outputDetails.moduleDir
        (\maybeExistingDetails ->
            case maybeExistingDetails of
                Just existingDetails ->
                    Just
                        (case ( existingDetails, outputDetails.fileName ) of
                            ( JustContent content, SingletonFile _ ) ->
                                JustContent content

                            ( JustContent content, ListItemFile functionName ) ->
                                Both content (Dict.singleton functionName inputDetails)

                            ( JustListItems listItems, SingletonFile functionName ) ->
                                Both ( functionName, inputDetails ) listItems

                            ( JustListItems listItems, ListItemFile functionName ) ->
                                JustListItems (Dict.union listItems (Dict.singleton functionName inputDetails))

                            ( Both content listItems, SingletonFile _ ) ->
                                Both content listItems

                            ( Both content listItems, ListItemFile functionName ) ->
                                Both content (Dict.union listItems (Dict.singleton functionName inputDetails))
                        )

                Nothing ->
                    case outputDetails.fileName of
                        SingletonFile functionName ->
                            Just (JustContent ( functionName, inputDetails ))

                        ListItemFile functionName ->
                            Just (JustListItems (Dict.singleton functionName inputDetails))
        )
        files



-- Generating file details --


type FileName
    = Hidden
    | Bracketed String
    | Normal String


type FileType
    = ListItemFile String
    | SingletonFile String


type alias OutputDetails =
    { moduleDir : List String
    , fileName : FileType
    }


outputPath : String -> Content.Path.Path -> Content.Internal.Output OutputDetails
outputPath pathSep filePath =
    let
        cleanFilePiece : String -> Result { message : String, terminate : Bool } FileName
        cleanFilePiece fullPiece =
            case Content.Path.parse fullPiece of
                Ok piecePath ->
                    if String.startsWith "." piecePath.name then
                        Ok Hidden

                    else if String.startsWith "[" piecePath.name && String.endsWith "]" piecePath.name then
                        Ok (Bracketed (String.classify piecePath.name))

                    else
                        Ok (Normal (String.classify piecePath.name))

                Err err ->
                    Err { terminate = True, message = err }

        continuePath : List FileName -> Result { message : String, terminate : Bool } { moduleDir : List String, fileName : Maybe FileType }
        continuePath pieces =
            case pieces of
                [] ->
                    Err
                        { terminate = False
                        , message = "Empty file path"
                        }

                file :: [] ->
                    case file of
                        Hidden ->
                            Err
                                { terminate = False
                                , message = "Ignoring hidden file"
                                }

                        Bracketed "Content" ->
                            Err
                                { terminate = True
                                , message = "Invalid [content].* file"
                                }

                        Bracketed fileName ->
                            Ok
                                { moduleDir = []
                                , fileName = Just (ListItemFile (String.decapitalize fileName))
                                }

                        Normal "Content" ->
                            Ok
                                { moduleDir = []
                                , fileName = Nothing
                                }

                        Normal fileName ->
                            Ok
                                { moduleDir = [ fileName ]
                                , fileName = Just (SingletonFile "content")
                                }

                folder :: restPath ->
                    let
                        fillInModuleDir : String -> { moduleDir : List String, fileName : Maybe FileType } -> { moduleDir : List String, fileName : Maybe FileType }
                        fillInModuleDir moduleName details =
                            { details | moduleDir = moduleName :: details.moduleDir }

                        fillInFileName : FileType -> { moduleDir : List String, fileName : Maybe FileType } -> { moduleDir : List String, fileName : Maybe FileType }
                        fillInFileName fileName details =
                            case details.fileName of
                                Just _ ->
                                    details

                                Nothing ->
                                    { details | fileName = Just fileName }
                    in
                    case folder of
                        Hidden ->
                            Err
                                { terminate = False
                                , message = "Ignoring hidden folder"
                                }

                        Bracketed "Content" ->
                            Err
                                { terminate = True
                                , message = "Invalid [content] folder"
                                }

                        Normal "Content" ->
                            Err
                                { terminate = True
                                , message = "Invalid content folder"
                                }

                        Bracketed folderName ->
                            continuePath restPath
                                |> Result.map (fillInFileName (ListItemFile folderName))

                        Normal folderName ->
                            continuePath restPath
                                |> Result.map (fillInModuleDir folderName)
                                |> Result.map (fillInFileName (SingletonFile folderName))
    in
    case Result.andThen continuePath (Result.combine (List.map cleanFilePiece (Content.Path.toList filePath))) of
        Ok details ->
            case details.fileName of
                Nothing ->
                    Content.Internal.Terminate "Invalid top-level content.* file"

                Just fileName ->
                    case details.moduleDir of
                        [] ->
                            Content.Internal.Terminate ("Invalid top-level [*].* file: " ++ Content.Path.format filePath)

                        _ ->
                            Content.Internal.Continue []
                                { moduleDir = "Content" :: details.moduleDir
                                , fileName = fileName
                                }

        Err err ->
            if err.terminate then
                Content.Internal.Terminate err.message

            else
                Content.Internal.Ignore [ Content.Internal.Info err.message ]
