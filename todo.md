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
