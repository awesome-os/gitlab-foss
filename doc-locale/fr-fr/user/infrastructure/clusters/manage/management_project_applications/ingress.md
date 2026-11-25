---
stage: Verify
group: Runner Core
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: Installer Ingress avec un projet de gestion de cluster
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

En supposant que vous ayez déjà un projet créé à partir d'un [modèle de projet de gestion](../../../../clusters/management_project_template.md), pour installer Ingress, vous devez décommenter cette ligne dans votre `helmfile.yaml` :

```yaml
  - path: applications/ingress/helmfile.yaml
```

Ingress est installé par défaut dans l'espace de nommage `gitlab-managed-apps` de votre cluster.

Vous pouvez personnaliser l'installation d'Ingress en mettant à jour le fichier `applications/ingress/values.yaml` dans votre projet de gestion de cluster. Référez-vous au [chart](https://github.com/kubernetes/ingress-nginx/tree/master/charts/ingress-nginx) pour les options de configuration disponibles.
