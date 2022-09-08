~~ warning: this program does not have comprehensive tests ~~

## Prerequisites

`elm-frontmatter` can be installed with NPM

## Installation

`npm install elm-frontmatter`  
Note `elm-frontmatter` has a peer dependency on `elm-format`, if using a NPM
version <7, you may also need to run `npm install elm-format`

## Setup

To get started, create a folder `/content` at the root of your application.  
In that `/content` directory, run `elm init` and `elm install thomasin/elm-frontmatter` to generate an `elm.json`.  
To decode your first frontmatter file you can populate:  

- a file `/content/index.md` with

```yaml
---
title: First page
---

I am using elm-frontmatter
```

- a file `/content/src/Content.elm` with

```elm
module Content exposing (decoder)

import Content.Decode as Decode
import Content.Type as Type

-- Required by the CLI app and cannot be removed or unexposed.
decoder : Type.Path -> Decode.QueryResult
decoder typePath =
    case typePath of
        Type.Single "Content.Index" ->
            Decode.frontmatter
                [ Decode.attribute "title" Decode.string
                ]
        _ ->
            Decode.throw

```

- and finally a `frontmatter.config.js` file with a config object that points to your newly made `/content`,
  directory, and the source directory of your Elm project. I think soon we will have CLI args (:

```js
module.exports = {
    inputDir: './content/', // Where to find the content frontmatter files, elm.json and Content.elm
    inputGlob: '**/*.md', // Which files to treat as frontmatter. Will always ignore files starting with a "."
    elmDir: './src/', // Which folder to add the generated `Content` directory to. This should be a root Elm folder.
}
```

Note that an auto-generated `Content/` folder will be created in the folder you specifiy as `elmDir`.

## Running

Run with `npx elm-frontmatter`

## Directory structure

```
.
└── content
    └── about
    |   └── content.md // <- /Content/About.elm
    ├── posts
    |   ├── content.md // <- /Content/Posts.elm
    |   ├── [first-post].md // <- /Content/Posts.elm
    |   ├── [second-post]  
    |   |   └── content.md // <- /Content/Posts.elm
    |   └── happy 
    |      └── ness.md // <- /Content/Posts/Happy/Ness.elm
    └── quote
        ├── first.md // <- /Content/Quote/First.elm
        └── second.md // <- /Content/Quote/Second.elm
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

The two types of files you can have are singleton or collection item files. List item files are surrounded by brackets `[file-name].md`.  
List item files share a type with other bracketed files at the same level, and will be generated into the same module.  
Singleton files will be turned into a `content` function in a module based on their file name. They can share a module with collection item functions, but two singleton functions won't share a module.  
When writing your `Content.elm#decoder` function, singleton files can be matched using `Content.Type.Single [ "Content", "Output", "Module", "Dir" ]`. List item files can be matched using `Content.Type.Collection [ "Content", "Output", "Module", "Dir" ]`.

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

