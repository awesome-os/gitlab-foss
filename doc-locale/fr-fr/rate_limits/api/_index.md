---
stage: none
group: unassigned
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
description: "Configurez les limites de débit pour des endpoints spécifiques de l'API GitLab."
title: "Limites de débit de l'API"
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

La plupart des requêtes API sont comptabilisées dans les [limites de débit générales par utilisateur et par adresse IP](../../administration/settings/user_and_ip_rate_limits.md). Pour certaines API, vous pouvez configurer une limite de débit distincte à la place. Une limite de débit d'API remplace les limites générales pour les requêtes adressées à cette API. Vous pouvez augmenter ou réduire la limite pour une seule API sans modifier les limites générales. Aucun autre comportement ne change.

Pour configurer ces limites, accédez à la zone **Admin** et sélectionnez **Paramètres** > **Réseau**.

## Limites de débit d'API disponibles {#available-api-rate-limits}

| API | Description |
|:----|:------------|
| [API des événements d'audit](../../administration/settings/rate-limit-on-audit-events-api.md) | Limite les requêtes qui récupèrent les événements d'audit d'instance, de groupe ou de projet. |
| [Points de terminaison dépréciés](deprecated.md) | Restreint les endpoints qui ont des remplaçants mais ne peuvent pas être supprimés sans rompre la compatibilité ascendante. |
| [API Groups](groups.md) | Limite les requêtes qui listent, récupèrent, créent et archivent des groupes, ainsi que celles qui listent et suppriment des membres de groupes. |
| [API Organizations](organizations.md) | Limite les requêtes qui créent des organisations. |
| [Registre de paquets](package-registry.md) | Limite les requêtes adressées à l'API Packages, que les projets en aval appellent pour résoudre les dépendances. |
| [API Projects](projects.md) | Limite les requêtes qui listent, récupèrent et créent des projets, ainsi que celles qui listent et suppriment des membres de projets. |
| [API Repository files](repository-files.md) | Limite les requêtes qui récupèrent, créent, mettent à jour et suppriment des fichiers dans un dépôt. |
| [API Users](users.md) | Limite les requêtes qui lisent les abonnés, le statut, les clés SSH et les clés GPG d'un utilisateur. |

## Sujets connexes {#related-topics}

- [Limites de fréquence](../_index.md)
- [Limites de débit non configurables](../non_configurable.md)
- [API REST](../../api/rest/_index.md)
