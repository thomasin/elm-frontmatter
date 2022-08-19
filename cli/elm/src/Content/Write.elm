module Content.Write exposing (Writer(..), concat, record, toFileString)

import Basics.Extra as Basics
import Content.Decode
import Content.Decode.Internal
import Content.Internal
import Elm.Syntax.Declaration
import Elm.Syntax.Exposing
import Elm.Syntax.Expression
import Elm.Syntax.Import
import Elm.Syntax.Module
import Elm.Syntax.TypeAnnotation
import Elm.Writer
import Json.Decode
import Json.Encode
import List.Extra as List
import String.Extra as String


type Writer
    = Writer
        { exposed : List Elm.Syntax.Exposing.TopLevelExpose
        , imports : List Elm.Syntax.Import.Import
        , declarations : ( List Elm.Syntax.Declaration.Declaration, List Elm.Syntax.Declaration.Declaration )
        , actions : List { with : String, args : Json.Encode.Value }
        }


toFileString : List String -> Writer -> String
toFileString moduleDir (Writer writer) =
    Elm.Writer.write
        (Elm.Writer.writeFile
            { moduleDefinition =
                Content.Internal.node
                    (Elm.Syntax.Module.NormalModule
                        { moduleName = Content.Internal.node (List.map String.classify moduleDir)
                        , exposingList =
                            Content.Internal.node
                                (Elm.Syntax.Exposing.Explicit
                                    (List.map Content.Internal.node writer.exposed)
                                )
                        }
                    )
            , imports = List.map Content.Internal.node writer.imports
            , declarations = List.map Content.Internal.node (List.unique (Basics.uncurry (++) writer.declarations))
            , comments = []
            }
        )


record : { functionName : String, functionType : String, inputFilePath : String, pathSep : String, frontmatter : Json.Decode.Value, documentation : Maybe String, decoder : Content.Decode.Internal.Declaration } -> Result Json.Decode.Error Writer
record args =
    let
        functionName : String
        functionName =
            String.decapitalize (String.camelize args.functionName)

        functionType : String
        functionType =
            String.classify args.functionType

        (Content.Decode.Internal.Declaration frontmatterDecoder) =
            args.decoder

        typeDeclaration : { exposed : Elm.Syntax.Exposing.TopLevelExpose, declaration : Elm.Syntax.Declaration.Declaration }
        typeDeclaration =
            toTypeDeclaration functionType args.decoder

        functionDeclarationResult : Result Json.Decode.Error { exposed : Elm.Syntax.Exposing.TopLevelExpose, declaration : Elm.Syntax.Declaration.Declaration, actions : List { with : String, args : Json.Encode.Value } }
        functionDeclarationResult =
            toFunctionDeclaration functionName functionType args.inputFilePath args.pathSep args.frontmatter args.documentation args.decoder
    in
    case functionDeclarationResult of
        Ok functionDeclaration ->
            Ok <|
                Writer
                    { exposed = [ typeDeclaration.exposed, functionDeclaration.exposed ]
                    , imports = frontmatterDecoder.imports
                    , declarations =
                        ( [ typeDeclaration.declaration ]
                        , [ functionDeclaration.declaration ]
                        )
                    , actions = functionDeclaration.actions
                    }

        Err decodeError ->
            Err decodeError


concat : List Writer -> Writer
concat writers =
    let
        writer : Writer -> { exposed : List Elm.Syntax.Exposing.TopLevelExpose, imports : List Elm.Syntax.Import.Import, declarations : ( List Elm.Syntax.Declaration.Declaration, List Elm.Syntax.Declaration.Declaration ), actions : List { with : String, args : Json.Encode.Value } }
        writer (Writer writer_) =
            writer_

        concatTuples : List ( List a, List a ) -> ( List a, List a )
        concatTuples =
            List.foldl
                (\( acc1, acc2 ) ( tup1, tup2 ) -> ( tup1 ++ acc1, tup2 ++ acc2 ))
                ( [], [] )
    in
    Writer
        { exposed = List.concat (List.map (.exposed << writer) writers)
        , imports = List.concat (List.map (.imports << writer) writers)
        , declarations = concatTuples (List.map (.declarations << writer) writers)
        , actions = List.concat (List.map (.actions << writer) writers)
        }


toTypeDeclaration : String -> Content.Decode.FrontmatterDecoder -> { exposed : Elm.Syntax.Exposing.TopLevelExpose, declaration : Elm.Syntax.Declaration.Declaration }
toTypeDeclaration typeName (Content.Decode.Internal.Declaration frontmatterDecoder) =
    { exposed = Elm.Syntax.Exposing.TypeOrAliasExpose typeName
    , declaration =
        Elm.Syntax.Declaration.AliasDeclaration
            { documentation = Nothing
            , name = Content.Internal.node typeName
            , generics = []
            , typeAnnotation =
                Content.Internal.node (Elm.Syntax.TypeAnnotation.Record frontmatterDecoder.typeAnnotation)
            }
    }


toFunctionDeclaration : String -> String -> String -> String -> Json.Decode.Value -> Maybe String -> Content.Decode.FrontmatterDecoder -> Result Json.Decode.Error { exposed : Elm.Syntax.Exposing.TopLevelExpose, declaration : Elm.Syntax.Declaration.Declaration, actions : List { with : String, args : Json.Encode.Value } }
toFunctionDeclaration functionName functionType inputPath pathSep rawContent documentation (Content.Decode.Internal.Declaration frontmatterDecoder) =
    case Json.Decode.decodeValue (frontmatterDecoder.jsonDecoder { inputFilePath = inputPath, pathSep = pathSep }) rawContent of
        Ok decodedFields ->
            Ok
                { exposed = Elm.Syntax.Exposing.FunctionExpose functionName
                , declaration =
                    Elm.Syntax.Declaration.FunctionDeclaration
                        { documentation = Maybe.map Content.Internal.node documentation
                        , signature =
                            Just
                                (Content.Internal.node
                                    { name = Content.Internal.node functionName
                                    , typeAnnotation = Content.Internal.node (Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( [], functionType )) [])
                                    }
                                )
                        , declaration =
                            Content.Internal.node
                                { name = Content.Internal.node functionName
                                , arguments = []
                                , expression =
                                    Content.Internal.node (Elm.Syntax.Expression.RecordExpr (List.map (\field -> Content.Internal.node ( Content.Internal.node field.keyName, Content.Internal.node field.expression )) decodedFields))
                                }
                        }
                , actions = List.concat (List.map .actions decodedFields)
                }

        Err decodeError ->
            Err decodeError
