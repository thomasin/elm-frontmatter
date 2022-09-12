module Content.Function exposing (FunctionType(..), Function, fromPath, PathError(..))

{-| This module is used by the CLI app, and is meant for parsing function details out of input file paths.

@docs FunctionType, Function, fromPath, PathError

-}

import Content.Internal
import Path
import Result.Extra as Result
import String.Extra as String


{-| Generated functions can either be singleton or collection item functions.

"Singleton" means that they don't share a type with any other function in the module.
These functions are made from paths with no brackets i.e `about.md`, `recipe/egg/content.md`

"Collection item" means that they do share types with other functions.
These functions are made from paths with surrounding brackets i.e `recipes/[egg].md`, `recipes/[egg]/content.md`

-}
type FunctionType
    = SingletonFunction
    | CollectionItemFunction


{-| Function overview
-}
type alias Function =
    { moduleDir : List String
    , name : String
    , type_ : FunctionType
    }


{-| Possible errors returned from `fromPath`
-}
type PathError
    = PathIsHidden
    | PathIsEmpty
    | PathIsInvalid String


{-| Turns a file path into a possible function
-}
fromPath : Path.Path -> Result PathError Function
fromPath filePath =
    let
        cleanFilePiece : String -> Result PathError Content.Internal.FileName
        cleanFilePiece fullPiece =
            case Path.fromString (Path.platform filePath) fullPiece of
                Ok piecePath ->
                    if String.startsWith "." (Path.name piecePath) then
                        Ok Content.Internal.Hidden

                    else if String.startsWith "[" (Path.name piecePath) && String.endsWith "]" (Path.name piecePath) then
                        Ok (Content.Internal.Bracketed (String.classify (Path.name piecePath)))

                    else
                        case String.classify (Path.name piecePath) of
                            "" ->
                                Ok Content.Internal.Empty

                            moduleName ->
                                Ok (Content.Internal.Normal moduleName)

                Err err ->
                    Err (PathIsInvalid err)

        continuePath : List Content.Internal.FileName -> Result PathError { moduleDir : List String, function : Maybe ( FunctionType, String ) }
        continuePath pieces =
            case pieces of
                [] ->
                    Err PathIsEmpty

                file :: [] ->
                    case file of
                        Content.Internal.Hidden ->
                            Err PathIsHidden

                        Content.Internal.Empty ->
                            Ok
                                { moduleDir = []
                                , function = Nothing
                                }

                        Content.Internal.Bracketed "Content" ->
                            Err (PathIsInvalid "Invalid [content].* file")

                        Content.Internal.Bracketed fileName ->
                            Ok
                                { moduleDir = []
                                , function = Just ( CollectionItemFunction, String.decapitalize fileName )
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
                            Err PathIsHidden

                        Content.Internal.Empty ->
                            continuePath restPath

                        Content.Internal.Bracketed "Content" ->
                            Err (PathIsInvalid "Invalid [content] folder")

                        Content.Internal.Normal "Content" ->
                            Err (PathIsInvalid "Invalid content folder")

                        Content.Internal.Bracketed folderName ->
                            continuePath restPath
                                |> Result.map (fillInFunction ( CollectionItemFunction, String.decapitalize folderName ))

                        Content.Internal.Normal folderName ->
                            continuePath restPath
                                |> Result.map (fillInModuleDir (String.classify folderName))
                                |> Result.map (fillInFunction ( SingletonFunction, "content" ))
    in
    case Result.andThen continuePath (Result.combine (List.map cleanFilePiece (Path.toList filePath))) of
        Ok details ->
            case details.function of
                Nothing ->
                    Err (PathIsInvalid "Invalid top-level content.* file")

                Just ( functionType, functionName ) ->
                    case details.moduleDir of
                        [] ->
                            Err (PathIsInvalid ("Invalid top-level [*].* file: " ++ Path.toString filePath))

                        _ ->
                            Ok
                                { moduleDir = details.moduleDir
                                , name = functionName
                                , type_ = functionType
                                }

        Err err ->
            Err err
