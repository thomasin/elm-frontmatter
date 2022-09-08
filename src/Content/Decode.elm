module Content.Decode exposing
    ( QueryResult, FrontmatterDecoder, fromSyntax, frontmatter, frontmatterWithoutBody, throw, ignore
    , Attribute, attribute, renameTo
    , Decoder, string, int, float, datetime, anonymousRecord, list, reference
    , DecodedAttribute
    )

{-| # Writing decoders



# Declaration

@docs QueryResult, FrontmatterDecoder, frontmatter, frontmatterWithoutBody, throw, ignore


# Attribute

@docs DecodedAttribute, Attribute, attribute, renameTo


# Basic decoders

@docs Decoder, fromSyntax, string, int, float, datetime, anonymousRecord, list, reference

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
import List.Extra as List
import String.Extra as String
import Path
import Time



-- Declaration --


{-| Declare a frontmatter decoder
-}
type alias FrontmatterDecoder =
    Content.Decode.Internal.Declaration


{-| The result of trying to find a decoder for a file
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
        ( Content.Decode.Internal.Declaration
            { typeAnnotation =
                \args ->
                    List.map (\(Content.Decode.Internal.Attribute attribute_) -> Content.Internal.node (attribute_.typeAnnotation args)) attributes
            , imports =
                \args ->
                    List.unique (List.concat (List.map (\(Content.Decode.Internal.Attribute attribute_) -> (attribute_.imports args)) attributes))
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
        ( Content.Decode.Internal.Declaration
            { typeAnnotation =
                \args ->
                    List.append
                        (List.map (\(Content.Decode.Internal.Attribute attribute_) -> Content.Internal.node ((attribute_.typeAnnotation args) )) attributes)
                        [ Content.Internal.node ( Content.Internal.node "body", Content.Internal.node (bodyDecoder_.typeAnnotation args) ) ]
            , imports =
                \args ->
                    List.unique (bodyDecoder_.imports args ++ List.concat (List.map (\(Content.Decode.Internal.Attribute attribute_) -> (attribute_.imports args)) attributes))
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


--| If this is returned with a `FrontmatterDecoder` from the main `decoder` function it will
--apply the frontmatter decoder to the matched file.

--    decoder : Content.Type.Path -> Content.Decode.QueryResult
--    decoder typePath =
--        case typePath of
--            Content.Type.Single [ "Content", "Index" ] ->
--                    Content.Decode.frontmatter Content.Decode.string
--                        [ Content.Decode.attribute "title" Content.Decode.string
--                        , Content.Decode.attribute "description" Content.Decode.string
--                        ]

--            _ ->
--                Content.Decode.throw


--using : FrontmatterDecoder -> QueryResult
--using =
--    Content.Decode.Internal.Found


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


{-| A YAML field
-}
type alias Attribute =
    Content.Decode.Internal.Attribute


{-| Decoded YAML field
-}
type alias DecodedAttribute =
    Content.Decode.Internal.DecodedAttribute


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
                Json.Decode.map (\value -> { keyName = (String.camelize keyName), expression = decoder.asExpression args value, actions = decoder.actions value })
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
            \args decodedList ->
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


{-| Decoder context passed down. Contains the file path of the file currently being decoded.
-}
type alias Context =
    Content.Decode.Internal.DecoderContext


{-| Create a decoder from a Syntax object.
    This lets you use custom JSON decoders to ensure the content you are receiving is valid.
    The Syntax object passed should be the Syntax object matching the output type of your JSON decoder.

    Content.Decode.fromSyntax Content.Decode.Syntax.int
        ( Json.Decode.int
            |> Json.Decode.andThen (\number ->
                if number > 0 then
                    Json.Decode.succeed number

                else
                    Json.Decode.fail "Only positive numbers supported"
            )
        )
-}
fromSyntax : Content.Decode.Syntax.Syntax Context a -> (Context -> Json.Decode.Decoder a) -> Decoder a
fromSyntax syntax jsonDecoder =
    Content.Decode.Internal.Decoder
        { typeAnnotation = syntax.typeAnnotation
        , imports = syntax.imports
        , jsonDecoder = jsonDecoder
        , asExpression = syntax.expression
        , actions = always []
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

        linkedFunctionIsInCurrentModule : Context -> Bool
        linkedFunctionIsInCurrentModule context =
            case Content.Function.fromPath context.inputFilePath of
                Ok currentFunction ->
                    currentFunction.moduleDir == moduleDir

                Err _ ->
                    False

    in
    Content.Decode.Internal.Decoder
        { typeAnnotation =
            \context ->
                if linkedFunctionIsInCurrentModule context then
                    Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( [], typeName )) []

                else
                    Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( moduleDir, typeName )) []
        , imports =
            \context ->
                if linkedFunctionIsInCurrentModule context then
                    []

                else
                    [ { moduleName = Content.Internal.node moduleDir
                      , moduleAlias = Nothing
                      , exposingList = Nothing
                      }
                    ]
        , jsonDecoder =
            \context ->
                Json.Decode.string
                    |> Json.Decode.andThen
                        (\filePathStr ->
                            case Path.fromString (Path.platform context.inputFilePath) filePathStr of
                                Ok filePath ->
                                    case Result.map2 Tuple.pair (Content.Function.fromPath context.inputFilePath) (Content.Function.fromPath filePath) of
                                        Ok ( currentFunction, linkedFunction ) ->
                                            if currentFunction.moduleDir == linkedFunction.moduleDir then
                                                Json.Decode.succeed ( [], linkedFunction.name )

                                            else
                                                Json.Decode.succeed ( linkedFunction.moduleDir, linkedFunction.name )

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
