---
name: Repositories
external_docs: https://docs.gitlab.com/api/repositories/
---
Use this API to manage [Git repositories](../../../../doc/user/project/repository/_index.md).

When the add changelog data operation adds to an existing changelog file, it places the new section by
the version headers already in the file. A version header must have the form `## X.Y.Z`. If the file
uses another form, such as `## vX.Y.Z`, new sections are appended to the end of the file. Migrate a
manually-managed changelog file to this format before you use the API.
