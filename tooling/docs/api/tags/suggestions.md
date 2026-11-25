---
name: Suggestions
external_docs: https://docs.gitlab.com/api/suggestions/
---
Use this API to manage [code suggestions](../../../../doc/user/project/merge_requests/reviews/suggestions.md).

Suggestions provide a way to propose specific changes that can be directly applied to the code.
You can programmatically create and apply code suggestions in merge request discussions with
this API. Every API call to suggestions must be authenticated.

To create a suggestion, use the Discussions API to create a new thread in the merge request diff.
