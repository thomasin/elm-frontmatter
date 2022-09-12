module Content.Module exposing (UndecodedModule, UndecodedFunction, Module, generate, GenerationError(..))

{-| This module is used by the CLI app, and is meant for generating an output module out of function details.
Decode a file from one or many JSON frontmatter values.

@docs UndecodedModule, UndecodedFunction, Module, generate, GenerationError

-}

import Content.Decode
import Content.Decode.Internal
import Content.Function
import Content.Type
import Content.Type.Internal
import Content.Write
import Dict
import Json.Decode
import Json.Encode
import Path
import Result.Extra as Result


{-| The outline of a yet-to-be-decoded module.
-}
type alias UndecodedModule =
    { dir : List String
    , functions : Dict.Dict String UndecodedFunction
    }


{-| Information about an undecoded function. `filePath` is the path
of the input file whose contents are decoded to form the function body.
`functionType` is whether this function's type is a singleton or collection item.
Singleton function types are named `Content`, whereas collection item types are named `CollectionItem`.
This gets converted to a [Content.Type.Path](Content-Type#Path) and used to query for the decoder.

    { filePath = "ingredients/egg.md", functionType = Content.Function.SingletonFunction, ... } == Content.Type.Single [ "Content", "Ingredients", "Egg" ]

    { filePath = "[recipes].md", functionType = Content.Function.CollectionItemFunction, ... } == Content.Type.Collection [ "Content", "Recipes" ]

`fileFrontmatter` contains the JSON encoded frontmatter value of the file. This function expects data
to be in the same shape as [gray-matter](https://github.com/jonschlinkert/gray-matter) output.

```json
{
    "content": "A string containing the file body",
    "data": {
        "title": "An object containing file attributes",
        "date": "2016-08-04T18:53:38.297Z"
    }
}
```

-}
type alias UndecodedFunction =
    { inputFilePath : Path.Path
    , type_ : Content.Function.FunctionType
    , frontmatter : Json.Decode.Value
    }


{-| The outputted file.
Actions are consumed by the `elm-frontmatter` npm package, and contain
instructions to be processed by JS code, currently limited to [image processing](Content-Decode-Image).
-}
type alias Module =
    { path : Path.Path
    , contents : String
    , actions : List { with : String, args : Json.Encode.Value }
    }


{-| Gets returnd when file generation fails
-}
type GenerationError
    = NoMatchingDecoder Content.Type.Path
    | ModuleIsEmpty
    | InvalidOutputPath String
    | DecoderError Content.Type.Path Json.Decode.Error


{-| Takes a function that can query for a decoder based on type path, and an undecoded module.
Returns the file path and contents for the decoded module.
-}
generate : Path.Platform -> (Content.Type.Path -> Content.Decode.QueryResult) -> UndecodedModule -> Result GenerationError Module
generate platform declarationGenerator outputModule =
    let
        toDeclarations : List ( String, UndecodedFunction ) -> Result GenerationError Content.Write.Writer
        toDeclarations functions =
            Result.map (Content.Write.concat << List.filterMap identity) <|
                Result.combine <|
                    List.map
                        (\( functionName, functionDetails ) ->
                            let
                                typePath : Content.Type.Path
                                typePath =
                                    Content.Type.Internal.fromFunctionType functionDetails.type_ outputModule.dir
                            in
                            case declarationGenerator typePath of
                                Content.Decode.Internal.Found (Content.Decode.Internal.Declaration frontmatterDecoder) ->
                                    Result.mapError (DecoderError typePath)
                                        (Result.map Just
                                            (Content.Write.record
                                                { functionName = functionName
                                                , functionType = Content.Type.toTypeName typePath
                                                , decoderContext =
                                                    Content.Decode.Internal.DecoderContext { inputFilePath = functionDetails.inputFilePath, moduleDir = outputModule.dir }
                                                , frontmatter = functionDetails.frontmatter
                                                , documentation = Just ("{-| Auto-generated from file " ++ Path.toString functionDetails.inputFilePath ++ "-}")
                                                , decoder = Content.Decode.Internal.Declaration frontmatterDecoder
                                                }
                                            )
                                        )

                                -- No decoder found for this module
                                Content.Decode.Internal.NotFound { throw } ->
                                    if throw then
                                        Err (NoMatchingDecoder typePath)

                                    else
                                        Ok Nothing
                        )
                        functions
    in
    case toDeclarations (Dict.toList outputModule.functions) of
        Ok (Content.Write.Writer decoded) ->
            if Content.Write.hasDeclarations (Content.Write.Writer decoded) then
                case Path.fromString platform (String.join "/" outputModule.dir ++ ".elm") of
                    Ok outputPath ->
                        Ok
                            { path = outputPath
                            , contents =
                                Content.Write.toFileString
                                    outputModule.dir
                                    (Content.Write.Writer decoded)
                            , actions = decoded.actions
                            }

                    Err _ ->
                        Err (InvalidOutputPath (String.join "/" outputModule.dir ++ ".elm"))

            else
                Err ModuleIsEmpty

        Err err ->
            Err err
