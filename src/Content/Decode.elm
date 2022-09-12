module Content.Decode exposing
    ( QueryResult, frontmatter, frontmatterWithoutBody, throw, ignore
    , Attribute, DecodedAttribute, attribute, renameTo
    , Decoder, Context, fromSyntax, string, int, float, datetime, anonymousRecord, list, reference
    )

{-| This is the main module used when writing decoders, and covers decoding basic Elm types like [`string`](#string), [`int`](#int), [`list`](#list)

**[Declarations](#declarations)** ⸺
From the `decoder` function in your `Content.elm` file, declare either success or failure finding a decoder.

**[Attributes](#attributes)** ⸺
Describe a YAML key/value pair

**[Decoders](#decoders)** ⸺
Decode YAML values into Elm types


## Declarations

@docs QueryResult, frontmatter, frontmatterWithoutBody, throw, ignore


## Attributes

@docs Attribute, DecodedAttribute, attribute, renameTo


## Decoders

@docs Decoder, Context, fromSyntax, string, int, float, datetime, anonymousRecord, list, reference

-}

import Content.Decode.Internal
import Content.Decode.Syntax
import Content.Function
import Content.Internal
import Content.Type
import Elm.Syntax.Expression
import Elm.Syntax.ModuleName
import Elm.Syntax.TypeAnnotation
import Json.Decode
import Json.Decode.Extra
import Json.Encode
import List.Extra as List
import Path
import String.Extra as String
import Time


{-| This type is returned from the main `decoder` function in your `Content.elm` file.
It is the result of trying to find a decoder for an input file.
Use [`frontmatter`](#frontmatter), [`frontmatterWithoutBody`](#frontmatterWithoutBody) to return a successfully found decoder, or [`throw`](#throw), [`ignore`](#ignore) if you can't match a decoder to the input.
-}
type alias QueryResult =
    Content.Decode.Internal.DeclarationResult


{-| Decode a frontmatter file. This will ignore the file body.


    decoder : Content.Type.Path -> Content.Decode.QueryResult
    decoder typePath =
        case typePath of
            Content.Type.Single [ "Content", "Index" ] ->
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
frontmatterWithoutBody : List Attribute -> QueryResult
frontmatterWithoutBody attributes =
    Content.Decode.Internal.Found
        (Content.Decode.Internal.Declaration
            { typeAnnotation =
                \args ->
                    List.map (\(Content.Decode.Internal.Attribute attribute_) -> Content.Internal.node (attribute_.typeAnnotation args)) attributes
            , imports =
                \args ->
                    List.unique (List.concat (List.map (\(Content.Decode.Internal.Attribute attribute_) -> attribute_.imports args) attributes))
            , jsonDecoder =
                \args ->
                    Json.Decode.field "data"
                        (Json.Decode.Extra.combine
                            (List.map (\(Content.Decode.Internal.Attribute attribute_) -> attribute_.jsonDecoder args) attributes)
                        )
            }
        )


{-| Decode a frontmatter file. This will include the file body as a `body` field in the generated record.
The first argument is the type that the body will be decoded as. Common options would be `Content.Decode.string` or `Content.Decode.Markdown.decode`


    decoder : Content.Type.Path -> Content.Decode.QueryResult
    decoder typePath =
        case typePath of
            Content.Type.Single [ "Content", "Index" ] ->
                Content.Decode.frontmatter Content.Decode.string
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
frontmatter : Decoder value -> List Attribute -> QueryResult
frontmatter bodyDecoder attributes =
    let
        (Content.Decode.Internal.Decoder bodyDecoder_) =
            bodyDecoder
    in
    Content.Decode.Internal.Found
        (Content.Decode.Internal.Declaration
            { typeAnnotation =
                \args ->
                    List.append
                        (List.map (\(Content.Decode.Internal.Attribute attribute_) -> Content.Internal.node (attribute_.typeAnnotation args)) attributes)
                        [ Content.Internal.node ( Content.Internal.node "body", Content.Internal.node (bodyDecoder_.typeAnnotation args) ) ]
            , imports =
                \args ->
                    List.unique (bodyDecoder_.imports args ++ List.concat (List.map (\(Content.Decode.Internal.Attribute attribute_) -> attribute_.imports args) attributes))
            , jsonDecoder =
                \args ->
                    Json.Decode.Extra.combine
                        (List.append
                            (List.map (\(Content.Decode.Internal.Attribute attribute_) -> Json.Decode.field "data" (attribute_.jsonDecoder args)) attributes)
                            [ Json.Decode.map (\value -> { keyName = "body", expression = bodyDecoder_.asExpression args value, actions = [] })
                                (Json.Decode.field "content" (bodyDecoder_.jsonDecoder args))
                            ]
                        )
            }
        )


{-| If this is returned from the main `decoder` function it will throw an error.
Useful when you want to ensure that all markdown files are handled.

    decoder : Content.Type.Path -> Content.Decode.QueryResult
    decoder typePath =
        case typePath of
            Content.Type.Single [ "Content", "Index" ] ->
                Content.Decode.frontmatterWithoutBody
                    [ Content.Decode.attribute "title" Content.Decode.string
                    , Content.Decode.attribute "description" Content.Decode.string
                    ]

            _ ->
                Content.Decode.throw

-}
throw : QueryResult
throw =
    Content.Decode.Internal.NotFound { throw = True }


{-| If this is returned from the main `decoder` function it won't do anything.
Useful when you want to allow markdown files to be created without having
a matching decoder yet.

    decoder : Content.Type.Path -> Content.Decode.Declaration
    decoder typePath =
        case typePath of
            Content.Type.Single [ "Content", "Index" ] ->
                Content.Decode.frontmatterWithoutBody
                    [ Content.Decode.attribute "title" Content.Decode.string
                    , Content.Decode.attribute "description" Content.Decode.string
                    ]

            _ ->
                Content.Decode.ignore

-}
ignore : QueryResult
ignore =
    Content.Decode.Internal.NotFound { throw = False }



-- Attribute --


{-| Represents a YAML key and value e.g. `title: Both the 'title' key and this string are part of the attribute`
Can be used in the [`frontmatter`](#frontmatter), [`frontmatterWithoutBody`](#frontmatterWithoutBody), or [`anonymousRecord`](#anonymousRecord) functions.
-}
type alias Attribute =
    Content.Decode.Internal.Attribute


{-| `attribute` is how you decode named YAML fields. They map
1-1 to the generated Elm. The fields
are generated in the order that they appear in the list.

    {- YAML:
    title: "Today's newspaper"
    description: "A pleasant walk"

    ---

    Tea
    -}

    Content.Decode.frontmatter Content.Decode.string
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
        { typeAnnotation =
            \args ->
                ( Content.Internal.node (String.camelize keyName), Content.Internal.node (decoder.typeAnnotation args) )
        , imports =
            \args ->
                decoder.imports args
        , jsonDecoder =
            \args ->
                Json.Decode.map (\value -> { keyName = String.camelize keyName, expression = decoder.asExpression args value, actions = decoder.actions value })
                    (Json.Decode.field keyName (decoder.jsonDecoder args))
        }


{-| Rename an attribute! This means you can parse the same frontmatter
field into multiple Elm attributes.

    Content.Decode.frontmatter Content.Decode.string
        [ Content.Decode.attribute "title" Content.Decode.string
        , Content.Decode.renameTo "slug" (Content.Decode.attribute "title" slugDecoder)
        ]

-}
renameTo : String -> Attribute -> Attribute
renameTo newName (Content.Decode.Internal.Attribute attribute_) =
    Content.Decode.Internal.Attribute
        { typeAnnotation =
            \args ->
                ( Content.Internal.node (String.camelize newName), Tuple.second (attribute_.typeAnnotation args) )
        , imports = attribute_.imports
        , jsonDecoder =
            \args ->
                Json.Decode.map (\decodedAttribute -> { decodedAttribute | keyName = String.camelize newName }) (attribute_.jsonDecoder args)
        }


{-| The result of [`attribute`](#attribute)'s json decoder.
It is an opaque type that the [`anonymousRecord`](#anonymousRecord) decodes and uses to construct the record expression.
-}
type alias DecodedAttribute =
    Content.Decode.Internal.DecodedAttribute


{-| Decode an anonymous record (We don't have typed records).
You have to create anonymous records with a list of `attribute`s.

    Content.Decode.frontmatter Content.Decode.string
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
            \args ->
                Elm.Syntax.TypeAnnotation.Record
                    (List.map (\(Content.Decode.Internal.Attribute attribute_) -> Content.Internal.node (attribute_.typeAnnotation args)) attributes)
        , imports =
            \args ->
                List.concat (List.map (\(Content.Decode.Internal.Attribute attribute_) -> attribute_.imports args) attributes)
        , jsonDecoder =
            \args ->
                Json.Decode.Extra.combine
                    (List.map (\(Content.Decode.Internal.Attribute attribute_) -> attribute_.jsonDecoder args) attributes)
        , asExpression =
            \_ decodedList ->
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


{-| Decoders turn JSON frontmatter data into Elm types and records
-}
type alias Decoder a =
    Content.Decode.Internal.Decoder a


{-| Decoder context passed down. Contains the file path and module directory of the file currently being decoded.
This is currently opaque, but if needed I can add a function to get the current file path.
-}
type alias Context =
    Content.Decode.Internal.DecoderContext


{-| Create a decoder from a Syntax object.
This lets you use custom JSON decoders to ensure the content you are receiving is valid.
The Syntax object passed should be the Syntax object matching the output type of your JSON decoder.

    Content.Decode.fromSyntax Content.Decode.Syntax.int
        (always [])
        (Json.Decode.int
            |> Json.Decode.andThen
                (\number ->
                    if number > 0 then
                        Json.Decode.succeed number

                    else
                        Json.Decode.fail "Only positive numbers supported"
                )
        )

-}
fromSyntax : Content.Decode.Syntax.Syntax Context a -> (a -> List { with : String, args : Json.Encode.Value }) -> (Context -> Json.Decode.Decoder a) -> Decoder a
fromSyntax syntax actions jsonDecoder =
    Content.Decode.Internal.Decoder
        { typeAnnotation = syntax.typeAnnotation
        , imports = syntax.imports
        , jsonDecoder = jsonDecoder
        , asExpression = syntax.expression
        , actions = actions
        }


{-| Decode strings

    Content.Decode.frontmatter Content.Decode.frontmatter
        [ Content.Decode.attribute "title" Content.Decode.string
        , Content.Decode.attribute "description" Content.Decode.string
        ]

-}
string : Decoder String
string =
    fromSyntax Content.Decode.Syntax.string
        (always [])
        (always Json.Decode.string)


{-| Decode ints

    Content.Decode.frontmatter Content.Decode.frontmatter
        [ Content.Decode.attribute "title" Content.Decode.string
        , Content.Decode.attribute "daysTillFullMoon" Content.Decode.int
        ]

-}
int : Decoder Int
int =
    fromSyntax Content.Decode.Syntax.int
        (always [])
        (always Json.Decode.int)


{-| Decode floats

    Content.Decode.frontmatter Content.Decode.frontmatter
        [ Content.Decode.attribute "title" Content.Decode.string
        , Content.Decode.attribute "bankAccountDollars" Content.Decode.float
        ]

-}
float : Decoder Float
float =
    fromSyntax Content.Decode.Syntax.float
        (always [])
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

    Content.Decode.frontmatter Content.Decode.string
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
        (always [])
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

    Content.Decode.frontmatter Content.Decode.string
        [ Content.Decode.attribute "strings" (Content.Decode.list Content.Decode.string)
        , Content.Decode.attribute "people"
            (Content.Decode.list (Content.Decode.reference (Content.Type.Collection [ "Content", "About", "People" ]))
        ]

This will generate the `Content/Index.elm` file

    type alias Content =
        { strings : List String
        , people : List Content.About.People.CollectionItem
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
    fromSyntax (Content.Decode.Syntax.list (Content.Decode.Internal.decoderToSyntax (Content.Decode.Internal.Decoder decoder)))
        (List.concatMap decoder.actions)
        (Json.Decode.list << decoder.jsonDecoder)


{-| References another content record. Given a markdown file `index.md` containing

```yaml
---
title: Index
about: about.md
person1: about/people/[person1].md
---

body text
```

And a decoder

    Content.Decode.frontmatter Content.Decode.string
        [ Content.Decode.attribute "about" (Content.Decode.reference (Content.Type.Single [ "Content", "About" ]))
        , Content.Decode.attribute "person1" (Content.Decode.reference (Content.Type.Collection [ "Content", "About", "People" ]))
        ]

This will generate the `Content/Index.elm` file

    import Content.About.People

    type alias Content =
        { about : Content.About.Content
        , person1 : Content.About.People.CollectionItem
        , body : String
        }

    content : Content
    content =
        { about = Content.About.content
        , person1 = Content.About.People.person1
        , body = "body text"
        }

-}
reference : Content.Type.Path -> Decoder ( Elm.Syntax.ModuleName.ModuleName, String )
reference typePath =
    let
        typeName : String
        typeName =
            Content.Type.toTypeName typePath

        moduleDir : List String
        moduleDir =
            Content.Type.toModuleDir typePath
    in
    Content.Decode.Internal.Decoder
        { typeAnnotation =
            \(Content.Decode.Internal.DecoderContext context) ->
                if context.moduleDir == moduleDir then
                    Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( [], typeName )) []

                else
                    Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( moduleDir, typeName )) []
        , imports =
            \(Content.Decode.Internal.DecoderContext context) ->
                if context.moduleDir == moduleDir then
                    []

                else
                    [ { moduleName = Content.Internal.node moduleDir
                      , moduleAlias = Nothing
                      , exposingList = Nothing
                      }
                    ]
        , jsonDecoder =
            \(Content.Decode.Internal.DecoderContext context) ->
                Json.Decode.string
                    |> Json.Decode.andThen
                        (\filePathStr ->
                            case Path.fromString (Path.platform context.inputFilePath) filePathStr of
                                Ok filePath ->
                                    case Content.Function.fromPath filePath of
                                        Ok linkedFunction ->
                                            if context.moduleDir == moduleDir then
                                                Json.Decode.succeed ( [], linkedFunction.name )

                                            else
                                                Json.Decode.succeed ( moduleDir, linkedFunction.name )

                                        Err Content.Function.PathIsHidden ->
                                            Json.Decode.fail ("Referenced path is hidden: " ++ filePathStr)

                                        Err Content.Function.PathIsEmpty ->
                                            Json.Decode.fail "Referenced path is empty"

                                        Err (Content.Function.PathIsInvalid message) ->
                                            Json.Decode.fail ("Referenced path is invalid (" ++ message ++ "): " ++ filePathStr)

                                Err _ ->
                                    Json.Decode.fail ("Invalid file path " ++ filePathStr)
                        )
        , asExpression =
            \_ ( moduleDir_, functionName ) ->
                Elm.Syntax.Expression.FunctionOrValue moduleDir_ (String.decapitalize functionName)
        , actions =
            always []
        }
