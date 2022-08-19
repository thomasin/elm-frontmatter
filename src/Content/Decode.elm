module Content.Decode exposing
    ( DecoderResult, FrontmatterDecoder, frontmatter, frontmatterWithoutBody, use, throw, ignore
    , Attribute, attribute
    , Decoder, string, int, float, datetime, anonymousRecord, list, link
    )

{-|


# Declaration

@docs DecoderResult, FrontmatterDecoder, frontmatter, frontmatterWithoutBody, use, throw, ignore


# Attribute

@docs Attribute, attribute


# Basic decoders

@docs Decoder, string, int, float, datetime, anonymousRecord, list, link

-}

import Content.Decode.Internal
import Content.Decode.Syntax
import Content.File
import Content.Internal
import Content.Path
import Content.Type
import Elm.Syntax.Expression
import Elm.Syntax.ModuleName
import Elm.Syntax.TypeAnnotation
import Json.Decode
import Json.Decode.Extra
import List.Extra as List
import Time



-- Declaration --


{-| Declare a frontmatter decoder
-}
type alias FrontmatterDecoder =
    Content.Decode.Internal.Declaration


{-| The result of trying to find a decoder for a file
-}
type alias DecoderResult =
    Content.Decode.Internal.DeclarationResult


{-| Decode a frontmatter file. This will ignore the file body.


    decoder : Content.Type.Path -> Content.Decode.DecoderResult
    decoder typePath =
        case typePath of
            Content.Type.Single "Content.Index" ->
                Content.Decode.use <|
                    Content.Decode.frontmatterWithoutBody
                        [ Content.Decode.attribute "title" Content.Decode.string
                        , Content.Decode.attribute "description" Content.Decode.string
                        ]

            _ ->
                Content.Decode.throw

    {- =>
       type alias Content =
           { title : String
           , description : String
           }

       content : Content
       content =
           { title = "Today's newspaper"
           , description = "A pleasant walk"
           }
    -}

-}
frontmatterWithoutBody : List Attribute -> FrontmatterDecoder
frontmatterWithoutBody attributes =
    Content.Decode.Internal.Declaration
        { typeAnnotation =
            List.map (\(Content.Decode.Internal.Attribute attribute_) -> Content.Internal.node attribute_.typeAnnotation) attributes
        , imports =
            List.unique (List.concat (List.map (\(Content.Decode.Internal.Attribute attribute_) -> attribute_.imports) attributes))
        , jsonDecoder =
            \args ->
                Json.Decode.field "data"
                    (Json.Decode.Extra.combine
                        (List.map (\(Content.Decode.Internal.Attribute attribute_) -> attribute_.jsonDecoder args) attributes)
                    )
        }


{-| Decode a frontmatter file. This will include the file body as a `body` field in the generated record.


    decoder : Content.Type.Path -> Content.Decode.DecoderResult
    decoder typePath =
        case typePath of
            Content.Type.Single "Content.Index" ->
                Content.Decode.use <|
                    Content.Decode.frontmatter
                        [ Content.Decode.attribute "title" Content.Decode.string
                        , Content.Decode.attribute "description" Content.Decode.string
                        ]

            _ ->
                Content.Decode.throw

    {- =>
       type alias Content =
           { title : String
           , description : String
           , body : String
           }

       content : Content
       content =
           { title = "Today's newspaper"
           , description = "A pleasant walk"
           , body = "Main content"
           }
    -}

-}
frontmatter : List Attribute -> FrontmatterDecoder
frontmatter attributes =
    let
        (Content.Decode.Internal.Decoder stringDecoder) =
            string
    in
    Content.Decode.Internal.Declaration
        { typeAnnotation =
            List.append
                (List.map (\(Content.Decode.Internal.Attribute attribute_) -> Content.Internal.node attribute_.typeAnnotation) attributes)
                [ Content.Internal.node ( Content.Internal.node "body", Content.Internal.node stringDecoder.typeAnnotation ) ]
        , imports =
            List.unique (List.concat (List.map (\(Content.Decode.Internal.Attribute attribute_) -> attribute_.imports) attributes))
        , jsonDecoder =
            \args ->
                Json.Decode.Extra.combine
                    (List.append
                        (List.map (\(Content.Decode.Internal.Attribute attribute_) -> Json.Decode.field "data" (attribute_.jsonDecoder args)) attributes)
                        [ Json.Decode.map (\value -> { keyName = "body", expression = stringDecoder.asExpression value, actions = [] })
                            (Json.Decode.field "content" (stringDecoder.jsonDecoder args))
                        ]
                    )
        }


{-| If this is returned with a `FrontmatterDecoder` from the main `decoder` function it will
apply the frontmatter decoder to the matched file.

    decoder : Content.Type.Path -> Content.Decode.DecoderResult
    decoder typePath =
        case typePath of
            Content.Type.Single "Content.Index" ->
                Content.Decode.use <|
                    Content.Decode.frontmatterWithoutBody
                        [ Content.Decode.attribute "title" Content.Decode.string
                        , Content.Decode.attribute "description" Content.Decode.string
                        ]

            _ ->
                Content.Decode.throw

-}
use : FrontmatterDecoder -> DecoderResult
use =
    Content.Decode.Internal.Found


{-| If this is returned from the main `decoder` function it will throw an error.
Useful when you want to ensure that all markdown files are handled.

    decoder : Content.Type.Path -> Content.Decode.DecoderResult
    decoder typePath =
        case typePath of
            Content.Type.Single "Content.Index" ->
                Content.Decode.use <|
                    Content.Decode.frontmatterWithoutBody
                        [ Content.Decode.attribute "title" Content.Decode.string
                        , Content.Decode.attribute "description" Content.Decode.string
                        ]

            _ ->
                Content.Decode.throw

-}
throw : DecoderResult
throw =
    Content.Decode.Internal.NotFound { throw = True }


{-| If this is returned from the main `decoder` function it won't do anything.
Useful when you want to allow markdown files to be created without having
a matching decoder yet.

    decoder : Content.Type.Path -> Content.Decode.Declaration
    decoder typePath =
        case typePath of
            Content.Type.Single "Content.Index" ->
                Content.Decode.use <|
                    Content.Decode.frontmatterWithoutBody
                        [ Content.Decode.attribute "title" Content.Decode.string
                        , Content.Decode.attribute "description" Content.Decode.string
                        ]

            _ ->
                Content.Decode.ignore

-}
ignore : DecoderResult
ignore =
    Content.Decode.Internal.NotFound { throw = False }



-- Attribute --


{-| A YAML field
-}
type alias Attribute =
    Content.Decode.Internal.Attribute


{-| Decoded YAML field
-}
type alias DecodedAttribute =
    Content.Decode.Internal.DecodedAttribute


{-| `attribute` is how you decode named YAML fields. They map
1-1 to the generated Elm and can't be renamed. The fields
are generated in the order that they appear in the list.

    {- YAML:
    title: "Today's newspaper"
    description: "A pleasant walk"

    ---

    Tea
    -}

    Content.Decode.frontmatter
        [ Content.Decode.attribute "title" Content.Decode.string
        , Content.Decode.attribute "description" Content.Decode.string
        ]

    {- =>
    type alias Content =
        { title : String
        , description : String
        , body : String
        }

    content : Content
    content =
        { title = "Today's newspaper"
        , description = "A pleasant walk"
        , body = "Tea"
        }
    -}

-}
attribute : String -> Decoder a -> Attribute
attribute keyName (Content.Decode.Internal.Decoder decoder) =
    Content.Decode.Internal.Attribute
        { typeAnnotation = ( Content.Internal.node keyName, Content.Internal.node decoder.typeAnnotation )
        , imports = decoder.imports
        , jsonDecoder =
            \args ->
                Json.Decode.map (\value -> { keyName = keyName, expression = decoder.asExpression value, actions = decoder.actions value })
                    (Json.Decode.field keyName (decoder.jsonDecoder args))
        }


{-| Decode an anonymous record (We don't have typed records yet).
You have to create anonymous records with a list of `attribute`s.

    Content.Decode.frontmatter
        [ Content.Decode.attribute "title" Content.Decode.string
        , Content.Decode.attribute "recordtest"
            (Content.Decode.anonymousRecord
                [ Content.Decode.attribute "field1" Content.Decode.string
                , Content.Decode.attribute "field2" Content.Decode.string
                ]
            )
        ]

-}
anonymousRecord : List Attribute -> Decoder (List DecodedAttribute)
anonymousRecord attributes =
    Content.Decode.Internal.Decoder
        { typeAnnotation =
            Elm.Syntax.TypeAnnotation.Record
                (List.map (\(Content.Decode.Internal.Attribute attribute_) -> Content.Internal.node attribute_.typeAnnotation) attributes)
        , imports =
            List.concat (List.map (\(Content.Decode.Internal.Attribute attribute_) -> attribute_.imports) attributes)
        , jsonDecoder =
            \args ->
                Json.Decode.Extra.combine
                    (List.map (\(Content.Decode.Internal.Attribute attribute_) -> attribute_.jsonDecoder args) attributes)
        , asExpression =
            \decodedList ->
                Elm.Syntax.Expression.RecordExpr
                    (List.map
                        (\decoded ->
                            Content.Internal.node ( Content.Internal.node decoded.keyName, Content.Internal.node decoded.expression )
                        )
                        decodedList
                    )
        , actions =
            \decodedList ->
                List.concat (List.map (\decoded -> decoded.actions) decodedList)
        }



-- Decoders --


{-| Decoders turn YAML data into Elm types and records
-}
type alias Decoder a =
    Content.Decode.Internal.Decoder a


{-| Create a decoder from a Syntax object.
-}
fromSyntax : Content.Decode.Syntax.Syntax a -> ({ pathSep : String, inputFilePath : String } -> Json.Decode.Decoder a) -> Decoder a
fromSyntax syntax jsonDecoder =
    Content.Decode.Internal.Decoder
        { typeAnnotation = syntax.typeAnnotation
        , imports = syntax.imports
        , jsonDecoder = jsonDecoder
        , asExpression = syntax.expression
        , actions = always []
        }


{-| Decode strings

    Content.Decode.frontmatter
        [ Content.Decode.attribute "title" Content.Decode.string
        , Content.Decode.attribute "description" Content.Decode.string
        ]

-}
string : Decoder String
string =
    fromSyntax Content.Decode.Syntax.string
        (always Json.Decode.string)


{-| Decode ints

    Content.Decode.frontmatter
        [ Content.Decode.attribute "title" Content.Decode.string
        , Content.Decode.attribute "daysTillFullMoon" Content.Decode.int
        ]

-}
int : Decoder Int
int =
    fromSyntax Content.Decode.Syntax.int
        (always Json.Decode.int)


{-| Decode floats

    Content.Decode.frontmatter
        [ Content.Decode.attribute "title" Content.Decode.string
        , Content.Decode.attribute "bankAccountDollars" Content.Decode.float
        ]

-}
float : Decoder Float
float =
    fromSyntax Content.Decode.Syntax.float
        (always Json.Decode.float)


{-| Decode Iso8601 formatted date strings. `elm/time` must be installed for the output to compile.

Given a markdown file `index.md` containing

```yaml
---
title: A list of people
tomorrow: 2016-08-04T18:53:38.297Z
---

body text
```

And a decoder

    Content.Decode.frontmatter
        [ Content.Decode.attribute "tomorrow" Content.Decode.datetime
        ]

This will generate the `Content/Index.elm` file

    import Time

    type alias Content =
        { tomorrow : Time.Posix
        , body : String
        }

    content : Content
    content =
        { tomorrow = Time.millisToPosix 1470336818297
        , body = "body text"
        }

-}
datetime : Decoder Time.Posix
datetime =
    fromSyntax Content.Decode.Syntax.datetime
        (always Json.Decode.Extra.datetime)


{-| Decode a list of items. Given a markdown file `index.md` containing

```yaml
---
title: A list of people
strings:
    - string1
    - string2
people:
    - about/people/[person1].md
    - about/people/[person2].md
---

body text
```

And a decoder

    Content.Decode.frontmatter
        [ Content.Decode.attribute "strings" (Content.Decode.list Content.Decode.string)
        , Content.Decode.attribute "people" (Content.Decode.list Content.Decode.link)
        ]

This will generate the `Content/Index.elm` file

    type alias Content =
        { strings : List String
        , people : List Content.About.People.ListItem
        , body : String
        }

    content : Content
    content =
        { strings = [ "string1", "string2" ]
        , people = [ Content.About.People.person1, Content.About.People.person2 ]
        , body = "body text"
        }

-}
list : Decoder a -> Decoder (List a)
list (Content.Decode.Internal.Decoder decoder) =
    fromSyntax (Content.Decode.Syntax.list (Content.Decode.Syntax.fromDecoder (Content.Decode.Internal.Decoder decoder)))
        (Json.Decode.list << decoder.jsonDecoder)


{-| Links to another content record. Given a markdown file `index.md` containing

```yaml
---
title: Index
about: about.md
person1: about/people/[person1].md
---

body text
```

And a decoder

    Content.Decode.frontmatter
        [ Content.Decode.attribute "about" Content.Decode.link
        , Content.Decode.attribute "person1" Content.Decode.link
        ]

This will generate the `Content/Index.elm` file

    import Content.About.People

    type alias Content =
        { about : Content.About.Content
        , person1 : Content.About.People.ListItem
        , body : String
        }

    content : Content
    content =
        { about = Content.About.content
        , person1 = Content.About.People.person1
        , body = "body text"
        }

-}
link : Content.Type.Path -> Decoder ( Elm.Syntax.ModuleName.ModuleName, String )
link typePath =
    let
        typeName : String
        typeName =
            Content.Type.toTypeName typePath

        moduleDir : List String
        moduleDir =
            Content.Type.toModuleDir typePath
    in
    Content.Decode.Internal.Decoder
        { typeAnnotation = Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( moduleDir, typeName )) []
        , imports =
            [ { moduleName = Content.Internal.node moduleDir
              , moduleAlias = Nothing
              , exposingList = Nothing
              }
            ]
        , jsonDecoder =
            \args ->
                Json.Decode.string
                    |> Json.Decode.andThen
                        (\filePathStr ->
                            case Content.Path.parse filePathStr of
                                Ok filePath ->
                                    case Content.File.outputPath args.pathSep filePath of
                                        Content.Internal.Continue _ outputDetails ->
                                            case outputDetails.fileName of
                                                Content.File.ListItemFile functionName ->
                                                    Json.Decode.succeed ( outputDetails.moduleDir, functionName )

                                                Content.File.SingletonFile functionName ->
                                                    Json.Decode.succeed ( outputDetails.moduleDir, functionName )

                                        _ ->
                                            Json.Decode.fail ("Couldn't find file path " ++ filePathStr)

                                Err _ ->
                                    Json.Decode.fail ("Invalid file path " ++ filePathStr)
                        )
        , asExpression =
            \( _, functionName ) ->
                Elm.Syntax.Expression.FunctionOrValue moduleDir functionName
        , actions =
            always []
        }
