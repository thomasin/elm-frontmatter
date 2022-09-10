~~ warning: this program does not have comprehensive tests ~~

## Installation

`npm install elm-frontmatter`  
`elm install thomasin/elm-frontmatter`  
Note `elm-frontmatter` has a peer dependency on `elm-format`, if using a NPM
version <7, you may also need to run `npm install elm-format`

## Setup

To get started, create a folder `/content` in the same directory as your `elm.json`.  

To decode your first frontmatter file you can populate:  

- a file `/content/index.md` with

```yaml
---
title: First page
---

woohoo
```

- a file `Content.elm` (placed in whichever folder your `Main.elm` is in) with

```elm
module Content exposing (decoder)

import Content.Decode as Decode
import Content.Type as Type

-- Required by the Node app and cannot be removed or unexposed.
decoder : Type.Path -> Decode.QueryResult
decoder typePath =
    case typePath of
        Type.Single "Content.Index" ->
            Decode.frontmatter Decode.string
                [ Decode.attribute "title" Decode.string
                ]
        _ ->
            Decode.throw

```

## Running

Run with `npx elm-frontmatter`

```bash
# Will look for frontmatter files in ./content/ and an elm.json file at ./elm.json.
# Will look for a Content.elm file in the first folder listed in your elm.json's `source-directories`,
# and will output the generated `Content` files into that same folder.
elm-frontmatter
# Will look for frontmatter files in ./md/ and an elm.json file at ./elm/elm.json.
# Will look for a Content.elm file in the first folder listed in your elm.json's `source-directories`,
# and will output the generated `Content` files into that same folder.
elm-frontmatter  --elm-json-dir=./elm ./md
# Will look for .md files in ./md/ and an elm.json file at ./elm/elm.json.
# Will look for a Content.elm file in the first folder listed in your elm.json's `source-directories`,
# and will output the generated `Content` files into that same folder.
elm-frontmatter --elm-dir='./src/elm'
# Will look for .md files in ./content/ and an elm.json file at ./elm.json.
# Will look for a Content.elm file at ./src/elm/,
# and will output the generated `Content` files also into ./src/elm.
elm-frontmatter --elm-dir='./src/elm'
# Same as previous except will generate new files without asking for confirmation.
# If `--yes` or `-y` is used, the `--elm-dir` argument must also be provided.
elm-frontmatter --elm-dir='./src/elm' -y
```

### Options

- `--glob`  
  Will only process frontmatter files in your content directory that match this glob.  
  Defaults to `**/*.md`.
- `--elm-json-dir`  
  The directory that contains your project's `elm.json` file.
  Defaults to `.` (current directory).
- `--elm-dir`  
  The directory that contains your project's `Main.elm` file.
  Defaults to the first directory in your `elm.json` `source-directories` array.
- `--yes`/`-y`  
  Set this to generate Elm files without asking for permission.  
  `--elm-dir` needs to be set to use this argument.

## Directory structure

```
.
└── content
    └── about
    |   └── content.md --> /Content/About.elm
    ├── posts
    |   ├── content.md --> /Content/Posts.elm
    |   ├── [first-post].md --> /Content/Posts.elm
    |   ├── [second-post]  
    |   |   └── content.md --> /Content/Posts.elm
    |   └── happy 
    |      └── ness.md --> /Content/Posts/Happy/Ness.elm
    └── quote
        ├── first.md --> /Content/Quote/First.elm
        └── second.md --> /Content/Quote/Second.elm
```

Once decoded, a generated `/Content` folder for this would look like

```
.
└── Content
    └── About.elm
    |   └── #content : Content
    ├── Posts.elm
    |   ├── #content : Content
    |   ├── #firstPost : CollectionItem
    |   └── #secondPost : CollectionItem
    ├── Posts
    |   └── Happy 
    |       └── Ness.elm
    |           └── #content : Content
    └── Quote
        ├── First.elm
        |   └── #content : Content
        └── Second.elm
            └── #content : Content
```

### content.md files

`content.md` files are treated similarly to `index.html` files in webpages. If there is one in a folder,
it will treat its containing folder name as its file name. This is useful if you want to keep images or other
information colocated with .md files e.g.

```
.
└── content
    └── people
        ├── [person1]
        |   ├── content.md
        |   └── thumbnail.jpg
        └── [person2]
            ├── content.md
            └── thumbnail.jpg
```

will generate

```
.
└── Content
    └── People.elm
        ├── #person1 : CollectionItem
        └── #person2 : CollectionItem
```

#### Notes:

- If you have two conflicting files, say `posts.md` and `posts/content.md`, one will be overwritten.  
- Since `content.md` files have special behaviour, having a top level `content` file or a `[content]` file/folder will throw an error and terminate the content generation.


### Singleton vs collection item files

The two types of files you can have are singleton or collection item files. Collection item files are surrounded by brackets `[file-name].md`.  
Collection item files share a type with other bracketed files at the same level, and will be generated into the same module.  
Singleton files will be turned into a `content` function in a module based on their file name. They can share a module with collection item functions, but two singleton functions won't share a module.  
When writing your `Content.elm#decoder` function, singleton files can be matched using `Content.Type.Single [ "Content", "Output", "Module", "Dir" ]`. Collection item files can be matched using `Content.Type.Collection [ "Content", "Output", "Module", "Dir" ]`.

```
module Content exposing (decoder)

import Content.Decode as Decode
import Content.Type as Type

decoder : Type.Path -> Decode.QueryResult
decoder typePath =
    case typePath of
        -- Will match `content/posts.md`
        Type.Single [ "Content", "Posts" ] ->
            Decode.frontmatter
                [ Decode.attribute "title" Decode.string
                , Decode.attribute "allPosts" (Decode.list (Decode.reference (Type.Collection [ "Content", "Posts" ])))
                ]

        -- Will match `content/posts/[first-post].md`, `content/posts/[second-post].md`, etc
        Type.Collection [ "Content", "Posts" ] ->
            Decode.frontmatter
                [ Decode.attribute "title" Decode.string
                , Decode.attribute "author" Decode.string
                , Decode.attribute "publishedAt" Decode.datetime
                ]
        _ ->
            Decode.throw
```

this decoder will generate a `Content/Posts.elm` module that is like

```elm
module Content.Posts exposing (Content, CollectionItem, content, firstPost, secondPost)

import Time


type alias Content =
    { title : String
    , allPosts : List CollectionItem
    }


type alias CollectionItem =
    { title : String
    , author : String
    , publishedAt : Time.Posix
    }


content : Content
content =
    ...


firstPost : CollectionItem
firstPost =
    ...


secondPost : CollectionItem
secondPost =
    ...
```

