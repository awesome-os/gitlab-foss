---
name: Dependency management
external_docs: https://docs.gitlab.com/api/dependency_list_export/
---
Use this API to retrieve a project's dependencies and to export
[dependency lists](../../../../doc/user/application_security/dependency_list/_index.md) for a project,
group, or pipeline.

Every call to these endpoints requires authentication. To retrieve a project's dependencies, the user
must be authorized to read the repository. To see vulnerabilities in a response, the user must also be
authorized to read the [project security dashboard](../../../../doc/user/application_security/security_dashboard/_index.md).
To create or download a dependency list export, the user must have the `read_dependency` permission,
and exports can be downloaded only by the user who created them.

Exports can be requested in different file formats. Some formats are only available for certain objects:

- `dependency_list`: A standard JSON object that lists the dependencies as key-value pairs. Available for projects.
- `sbom`: A CycloneDX 1.4 bill of materials. Available for pipelines.
- `cyclonedx_1_6_json`: A CycloneDX 1.6 bill of materials. Available for projects.
- `json_array`: A flat JSON array that contains component objects. Available for groups.
- `csv`: A comma-separated values (CSV) document. Available for projects and groups.
