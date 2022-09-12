- [*] show warning when content decoder not found - dont error
- [*] include a "this file has been auto generated" comment in content .elm files
- [*] replace entire content folder in one go
- [ ] cli args/help messages
- [ ] half decent docs
- [ ] half decent tests
- [ ] half decent errors
- [ ] fix slow elm-json install

## v2 thoughts

- a decoder for file paths to give  more control over file structure,
  whether files belong to a list or not. it would also mean you could have posts
  with titles like `2022-05-06-this-is-a-blog-post.md` or `02-getting-started.md`
  and actually make use of (or ignore) the titles.

## v3 thoughts

- change the api to be more like hakyll, with a path matcher and compiler for different file types.
  something something vaguely like this but simpler.
  would probably want to start by creating a separate file/glob matcher package.
  the compiler stuff is just rebranded Decode.frontmatter

```elm
Match.oneOf
    [ Match.when (Match.path [ "about", "people" ] |> Match.collection)
        ( Compile.frontmatter
            [ Decode.attribute "title" Decode.string
            ]
        )

    , Match.when (Match.path [ "about" ])
        ( Compile.rewritePath (Path.Path ...) 
            Compile.string
        )

    , Match.when (Match.path [ "about" ])
        ( Compile.markup
            ...
        )
    ]
```

- output something a bit cleaner. maybe

```elm
type alias File metadata body =
    { file : Path.Path
    , metadata : metadata
    , body : body
    }
```
