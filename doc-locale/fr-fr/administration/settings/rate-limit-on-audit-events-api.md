---
stage: Software Supply Chain Security
group: Compliance
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: "Limite de débit sur l'API des événements d'audit"
---

{{< details >}}

- Édition : GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

{{< history >}}

- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/248055) dans GitLab 19.4 pour l'API des événements d'audit d'instance.
- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/253781) dans GitLab 19.5 pour l'API des événements d'audit de projet.
- [Introduit](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/255336) dans GitLab 19.5 pour l'API des événements d'audit de groupe.

{{< /history >}}

Vous pouvez configurer des limites de débit pour les requêtes vers trois API :

- L'[API des événements d'audit d'instance](../../api/audit_events.md#instance-audit-events). La limite de débit est par minute et par utilisateur. La valeur par défaut est 200.
- L'[API des événements d'audit de groupe](../../api/audit_events.md#group-audit-events). La limite de débit est par minute, par utilisateur et par groupe. La valeur par défaut est 200.
- L'[API des événements d'audit de projet](../../api/audit_events.md#project-audit-events). La limite de débit est par minute, par utilisateur et par projet. La valeur par défaut est 200.

Les requêtes dépassant l'une de ces limites de débit renvoient un code de statut `429 Too Many Requests` et sont enregistrées dans le fichier `auth.log`.

- La limite de débit de l'API des événements d'audit d'instance s'applique à la fois à `GET /audit_events` et à `GET /audit_events/:id`.
- La limite de débit de l'API des événements d'audit de groupe s'applique à la fois à `GET /groups/:id/audit_events` et à `GET /groups/:id/audit_events/:audit_event_id`.
- La limite de débit de l'API des événements d'audit de projet s'applique à la fois à `GET /projects/:id/audit_events` et à `GET /projects/:id/audit_events/:audit_event_id`.

Par exemple, si vous définissez une limite de 200, les requêtes vers ces endpoints qui dépassent un débit de 200 en une minute sont bloquées. L'accès est rétabli après une minute.

## Modifier les limites de débit {#change-the-rate-limits}

Prérequis :

- Disposer d'un accès administrateur.

Pour modifier une limite de débit :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Réseau**.
1. Développez **Limites de débit de l'API des événements d'audit**.
1. Modifiez la valeur de la limite de débit que vous souhaitez mettre à jour. Pour désactiver une limite de débit, définissez la valeur sur `0`.
1. Sélectionnez **Enregistrer les modifications**.
