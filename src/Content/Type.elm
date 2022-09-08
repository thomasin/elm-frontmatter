module Content.Type exposing (Path(..), toString, toTypeName, toModuleDir)

{-|

# Content.Type

This is passed in to the main `decoder` function in `Content.elm`, and can be matched
against to assign decoders based on module directory and either single or collection item type.

@docs Path, toString, toTypeName, toModuleDir

-}

{-|
A type path, e.g. `Single [ "Content", "About" ]` or `Collection [ "Content", "People" ]`
The List String is the module that the type is contained in.  
`Single` indicates this type/decoder only applies to one function/input frontmatter file.
`Collection` indicates that type/decoder type will apply to multiple functions/input frontmatter files.
-}
type Path
    = Single (List String)
    | Collection (List String)


{-|
```
Content.Type.toString (Content.Type.Single [ "Recipes", "Egg" ]) == "Recipes.Egg.Content"
Content.Type.toString (Content.Type.Collection [ "Recipes", "Ingredients" ]) == "Recipes.Ingredients.CollectionItem"
```
-}
toString : Path -> String
toString path =
    case path of
        Single modules ->
            String.join "." modules ++ "." ++ toTypeName path

        Collection modules ->
            String.join "." modules ++ "." ++ toTypeName path


{-|
```
Content.Type.toTypeName (Content.Type.Single [ "Recipes", "Egg" ]) == "Content"
Content.Type.toTypeName (Content.Type.Collection [ "Recipes", "Ingredients" ]) == "CollectionItem"
```
-}
toTypeName : Path -> String
toTypeName path =
    case path of
        Single _ ->
            "Content"

        Collection _ ->
            "CollectionItem"


{-|
```
Content.Type.toModuleDir (Content.Type.Single [ "Recipes", "Egg" ]) == [ "Recipes", "Egg" ]
Content.Type.toModuleDir (Content.Type.Collection [ "Recipes", "Ingredients" ]) == [ "Recipes", "Ingredients" ]
```
-}
toModuleDir : Path -> List String
toModuleDir path =
    case path of
        Single modules ->
            modules

        Collection modules ->
            modules
