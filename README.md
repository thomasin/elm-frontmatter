elm-frontmatter - decode frontmatter files into elm

With a folder structure like

```
content/
    about.md
    about/
        recipes/
            [egg].md
            [water].md
    ingredients/
        [croissant]/
            content.md
```

generate

```
Content/
    About.elm
    About/
        Recipes.elm (with records egg, water)
    Ingredients.elm (with record croissant)
```

& with a frontmatter file (`about/recipes.md`) like

```yaml
---
title: Recipes
slug: recipes
recipes: 2
banner: recipe-img.jpg
---
all recipe content
```

using this decoder
```elm
module Content exposing (decoder)

import Content.Decode as Decode
import Content.Decode.Image as Image
import Content.Type as Type


imageCopyArgs : Image.CopyArgs
imageCopyArgs =
    { copyToDirectory = "../image-gen/"
    , publicDirectory = "/static/"
    }


decoder : Type.Path -> Decode.DecoderResult
decoder typePath =
    case typePath of
        Type.Single "Content.About.Recipes" ->
            Decode.use <| Decode.frontmatter
                [ Decode.attribute "title" Decode.string
                , Decode.attribute "slug" Decode.string
                , Decode.attribute "recipes" Decode.int
                , Decode.attribute "banner"
                    ( Image.process imageCopyArgs [ Image.width 600 ] )
                ]

        _ ->
            Decode.throw
```

decode into an Elm file like

```elm
module Content.About.Recipes exposing (Content, content)


type alias Content =
    { title : String
    , slug : String
    , recipes : Int
    , banner : String
    , body : String
    }


content : Content
content = 
    { title = "Recipes"
    , slug = "recipes"
    , recipes = 2
    , banner = "/static/recipe-img.jpg"
    , body = "all recipe content"
    }
```

## how to use

1. Create a `/content` folder at the same level as your `package.json` containing .md files with frontmatter contents.
2. Create a `Content.elm` file at the root of your Elm files exposing a decoder function describing the frontmatter files.
3. Create a `frontmatter.config.js` file at the same level as your `package.json`
4. Run `npx run elm-frontmatter` to generate Elm files within a `Content` folder.

## config

Config is kept in a `frontmatter.config.js` file on the same level as your `package.json`.

```js
module.exports = {
    inputDir: './content/',
    inputGlob: '**/*.md',
    elmDir: './src/',
}
```

- `inputDir` is where the program will look for your frontmatter files
- `inputGlob` is how the program will collect the frontmatter files
- `elmDir` is where the program will place the generated `Content` folder containing output Elm files.
    It is also where it will search for the `Content.elm` file containing the decoder.