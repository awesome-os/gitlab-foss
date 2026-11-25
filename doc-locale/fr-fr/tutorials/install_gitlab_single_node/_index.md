---
stage: GitLab Delivery
group: Operate
info: To determine the technical writer assigned to the Stage/Group associated with this page, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments>
title: 'Tutoriel : installer et sécuriser une instance GitLab sur nœud unique'
---

{{< details >}}

- Édition : Gratuite, GitLab Premium, GitLab Ultimate
- Offre : GitLab Self-Managed

{{< /details >}}

<!-- vale gitlab_base.FutureTense = NO -->

Dans ce tutoriel, vous apprendrez à installer et à configurer de manière sécurisée une instance GitLab à nœud unique pouvant accueillir jusqu'à [20 RPS ou 1 000 utilisateurs](../../administration/reference_architectures/1k_users.md).

Pour installer une instance GitLab à nœud unique et la configurer de manière sécurisée :

1. [Sécuriser le serveur](#secure-the-server)
1. [Installer GitLab](#install-gitlab)
1. [Configurer GitLab](#configure-gitlab)
1. [Étapes suivantes](#next-steps)

## Avant de commencer {#before-you-begin}

- Un nom de domaine et une [configuration DNS](https://docs.gitlab.com/omnibus/settings/dns/) correcte.
- Un serveur Debian avec les spécifications minimales suivantes :
  - 8 vCPU
  - 7,2 Go de mémoire
  - Suffisamment d'espace disque pour tous vos dépôts. En savoir plus sur les [exigences de stockage](../../install/requirements.md).

## Sécuriser le serveur {#secure-the-server}

Avant d'installer GitLab, commencez par configurer votre serveur pour le rendre un peu plus sécurisé.

### Configurer le pare-feu {#configure-the-firewall}

Vous devez ouvrir les ports 22 (SSH), 80 (HTTP) et 443 (HTTPS). Vous pouvez effectuer cette opération via la console de votre fournisseur cloud ou au niveau du serveur.

Dans cet exemple, vous allez configurer le pare-feu à l'aide de [`ufw`](https://wiki.ubuntu.com/UncomplicatedFirewall). Vous allez refuser l'accès à tous les ports, autoriser les ports 80 et 443, et enfin, appliquer une limite de débit à l'accès au port 22. `ufw` peut refuser les connexions d'une adresse IP ayant tenté d'initier 6 connexions ou plus au cours des 30 dernières secondes.

1. Installez `ufw` :

   ```shell
   sudo apt install ufw
   ```

1. Activez et démarrez le service `ufw` :

   ```shell
   sudo systemctl enable --now ufw
   ```

1. Refusez l'accès à tous les autres ports sauf ceux requis :

   ```shell
   sudo ufw default deny
   sudo ufw allow http
   sudo ufw allow https
   sudo ufw limit ssh/tcp
   ```

1. Enfin, activez les paramètres. La commande suivante ne doit être exécutée qu'une seule fois, lors de la première installation du package. Répondez oui (`y`) lorsque vous y êtes invité :

   ```shell
   sudo ufw enable
   ```

1. Vérifiez que les règles sont présentes :

   ```shell
   $ sudo ufw status

   Status: active

   To                         Action      From
   --                         ------      ----
   80/tcp                     ALLOW       Anywhere
   443                        ALLOW       Anywhere
   22/tcp                     LIMIT       Anywhere
   80/tcp (v6)                ALLOW       Anywhere (v6)
   443 (v6)                   ALLOW       Anywhere (v6)
   22/tcp (v6)                LIMIT       Anywhere (v6)
   ```

### Configurer le serveur SSH {#configure-the-ssh-server}

Pour sécuriser davantage votre serveur, configurez SSH pour accepter l'authentification par clé publique et désactiver certaines fonctionnalités qui représentent des risques de sécurité potentiels.

1. Ouvrez `/etc/ssh/sshd_config` avec votre éditeur et assurez-vous que les éléments suivants sont présents :

   ```plaintext
   PubkeyAuthentication yes
   PasswordAuthentication yes
   UsePAM yes
   UseDNS no
   AllowTcpForwarding no
   X11Forwarding no
   PrintMotd no
   PermitTunnel no
   # Allow client to pass locale environment variables
   AcceptEnv LANG LC_*
   # override default of no subsystems
   Subsystem       sftp    /usr/lib/openssh/sftp-server
   # Protocol adjustments, these would be needed/recommended in a FIPS or
   # FedRAMP deployment, and use only strong and proven algorithm choices
   Protocol 2
   Ciphers aes128-ctr,aes192-ctr,aes256-ctr
   HostKeyAlgorithms ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521
   KexAlgorithms ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521
   Macs hmac-sha2-256,hmac-sha2-512
   ```

1. Enregistrez le fichier et redémarrez le serveur SSH :

   ```shell
   sudo systemctl restart ssh
   ```

   Si le redémarrage de SSH échoue, vérifiez que vous n'avez pas d'entrées en double dans `/etc/ssh/sshd_config`.

### S'assurer que seuls les utilisateurs autorisés utilisent SSH pour l'accès Git {#ensure-only-authorized-users-are-using-ssh-for-git-access}

Ensuite, assurez-vous que les utilisateurs ne peuvent pas récupérer des projets via SSH s'ils ne disposent pas d'un compte GitLab valide pouvant effectuer des opérations Git via SSH.

Pour s'assurer que seuls les utilisateurs autorisés utilisent SSH pour l'accès Git :

1. Ajoutez ce qui suit à votre fichier `/etc/ssh/sshd_config` :

   ```plaintext
   # Ensure only authorized users are using Git
   AcceptEnv GIT_PROTOCOL
   ```

1. Enregistrez le fichier et redémarrez le serveur SSH :

   ```shell
   sudo systemctl restart ssh
   ```

### Effectuer quelques ajustements du noyau {#make-some-kernel-adjustments}

Les ajustements du noyau n'éliminent pas complètement la menace d'une attaque, mais ils ajoutent une couche de sécurité supplémentaire.

1. Ouvrez un nouveau fichier avec votre éditeur sous `/etc/sysctl.d`, par exemple `/etc/sysctl.d/99-gitlab-hardening.conf`, et ajoutez ce qui suit.

   > [!note]
   > Le nom et le répertoire source déterminent l'ordre de traitement, ce qui est important car le dernier paramètre traité peut remplacer les précédents.

   ```plaintext
   ##
   ## The following help mitigate out of bounds, null pointer dereference, heap and
   ## buffer overflow bugs, use-after-free etc from being exploited. It does not 100%
   ## fix the issues, but seriously hampers exploitation.
   ##
   # Default is 65536, 4096 helps mitigate memory issues used in exploitation
   vm.mmap_min_addr=4096
   # Default is 0, randomize virtual address space in memory, makes vuln exploitation
   # harder
   kernel.randomize_va_space=2
   # Restrict kernel pointer access (for example, cat /proc/kallsyms) for exploit assistance
   kernel.kptr_restrict=2
   # Restrict verbose kernel errors in dmesg
   kernel.dmesg_restrict=1
   # Restrict eBPF
   kernel.unprivileged_bpf_disabled=1
   net.core.bpf_jit_harden=2
   # Prevent common use-after-free exploits
   vm.unprivileged_userfaultfd=0

   ## Networking tweaks ##
   ##
   ## Prevent common attacks at the IP stack layer
   ##
   # Prevent SYNFLOOD denial of service attacks
   net.ipv4.tcp_syncookies=1
   # Prevent time wait assassination attacks
   net.ipv4.tcp_rfc1337=1
   # IP spoofing/source routing protection
   net.ipv4.conf.all.rp_filter=1
   net.ipv4.conf.default.rp_filter=1
   net.ipv6.conf.all.accept_ra=0
   net.ipv6.conf.default.accept_ra=0
   net.ipv4.conf.all.accept_source_route=0
   net.ipv4.conf.default.accept_source_route=0
   net.ipv6.conf.all.accept_source_route=0
   net.ipv6.conf.default.accept_source_route=0
   # IP redirection protection
   net.ipv4.conf.all.accept_redirects=0
   net.ipv4.conf.default.accept_redirects=0
   net.ipv4.conf.all.secure_redirects=0
   net.ipv4.conf.default.secure_redirects=0
   net.ipv6.conf.all.accept_redirects=0
   net.ipv6.conf.default.accept_redirects=0
   net.ipv4.conf.all.send_redirects=0
   net.ipv4.conf.default.send_redirects=0
   ```

1. Lors du prochain redémarrage du serveur, les valeurs seront chargées automatiquement. Pour les charger immédiatement :

   ```shell
   sudo sysctl --system
   ```

Excellent travail, vous avez terminé les étapes pour sécuriser votre serveur ! Vous êtes maintenant prêt à installer GitLab.

## Installer GitLab {#install-gitlab}

Maintenant que votre serveur est configuré, installez GitLab :

1. Installez et configurez les dépendances nécessaires :

   ```shell
   sudo apt update
   sudo apt install -y curl openssh-server ca-certificates perl locales
   ```

1. Configurez la langue du système :

   1. Modifiez `/etc/locale.gen` et assurez-vous que `en_US.UTF-8` est décommenté.
   1. Regénérez les langues :

      ```shell
      sudo locale-gen
      ```

1. Ajoutez le dépôt de packages GitLab et installez le package :

   ```shell
   curl --location "https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh" | sudo bash
   ```

1. Installez le package GitLab. Fournissez un mot de passe fort avec `GITLAB_ROOT_PASSWORD` et remplacez `EXTERNAL_URL` par le vôtre. N'oubliez pas d'inclure `https` dans l'URL afin qu'un certificat Let's Encrypt soit émis.

   ```shell
   sudo GITLAB_ROOT_PASSWORD="strong password" EXTERNAL_URL="https://gitlab.example.com" apt install gitlab-ee
   ```

   Pour en savoir plus sur le certificat Let's Encrypt ou pour utiliser le vôtre, consultez comment [configurer GitLab avec TLS](https://docs.gitlab.com/omnibus/settings/ssl/).

   Si le mot de passe que vous avez défini n'a pas été pris en compte, consultez les informations sur la [réinitialisation du mot de passe du compte root](../../security/reset_user_password.md#reset-the-root-password).
1. Au bout de quelques minutes, GitLab est installé. Connectez-vous en utilisant l'URL que vous avez définie dans `EXTERNAL_URL`. Utilisez `root` comme nom d'utilisateur et le mot de passe que vous avez défini dans `GITLAB_ROOT_PASSWORD`.

Il est maintenant temps de configurer GitLab !

## Configurer GitLab {#configure-gitlab}

GitLab est fourni avec des options de configuration par défaut raisonnables. Dans cette section, nous allons les modifier pour ajouter davantage de fonctionnalités et renforcer la sécurité de GitLab.

Pour certaines options, vous utiliserez l'interface utilisateur de la zone **Admin**, et pour d'autres, vous modifierez `/etc/gitlab/gitlab.rb`, le fichier de configuration de GitLab.

### Configurer NGINX {#configure-nginx}

NGINX est utilisé pour servir l'interface web permettant d'accéder à l'instance GitLab. Pour plus d'informations sur la configuration de NGINX afin de le rendre plus sécurisé, consultez la section [renforcement de NGINX](../../security/hardening_configuration_recommendations.md#nginx).

### Configurer les e-mails {#configure-emails}

Ensuite, vous allez configurer un service de messagerie. Les e-mails sont importants pour vérifier les nouveaux comptes utilisateurs, réinitialiser les mots de passe et vous informer de l'activité GitLab.

#### Configurer SMTP {#configure-smtp}

Dans ce tutoriel, vous allez configurer un serveur [SMTP](https://docs.gitlab.com/omnibus/settings/smtp/) et utiliser le fournisseur SMTP [Mailgun](https://www.mailgun.com/).

Commencez par créer un fichier chiffré qui contiendra les identifiants de connexion, puis configurez SMTP pour le package Linux :

1. Créez un fichier YAML (par exemple `smtp.yaml`) contenant les identifiants du serveur SMTP.

   Votre mot de passe SMTP ne doit contenir aucun délimiteur de chaîne utilisé en Ruby ou YAML (par exemple, `'`) afin d'éviter tout comportement inattendu lors du traitement des paramètres de configuration.

   ```shell
   user_name: '<SMTP user>'
   password: '<SMTP password>'
   ```

1. Chiffrez le fichier :

   ```shell
   cat smtp.yaml | sudo gitlab-rake gitlab:smtp:secret:write
   ```

   Par défaut, le fichier chiffré est stocké sous `/var/opt/gitlab/gitlab-rails/shared/encrypted_settings/smtp.yaml.enc`.
1. Supprimez le fichier YAML :

   ```shell
   rm -f smtp.yaml
   ```

1. Modifiez `/etc/gitlab/gitlab.rb` et configurez le reste des paramètres SMTP. Assurez-vous que `gitlab_rails['smtp_user_name']` et `gitlab_rails['smtp_password']` ne sont pas présents, car nous les avons déjà configurés comme chiffrés.

   ```ruby
   gitlab_rails['smtp_enable'] = true
   gitlab_rails['smtp_address'] = "smtp.mailgun.org" # or smtp.eu.mailgun.org
   gitlab_rails['smtp_port'] = 587
   gitlab_rails['smtp_authentication'] = "plain"
   gitlab_rails['smtp_enable_starttls_auto'] = true
   gitlab_rails['smtp_domain'] = "<mailgun domain>"
   ```

1. Enregistrez le fichier et reconfigurez GitLab :

   ```shell
   sudo gitlab-ctl reconfigure
   ```

Vous devriez maintenant pouvoir envoyer des e-mails. Pour tester que la configuration a fonctionné :

1. Accédez à la console Rails :

   ```shell
   sudo gitlab-rails console
   ```

1. Exécutez la commande suivante dans l'invite de la console pour que GitLab envoie un e-mail de test :

   ```ruby
   Notify.test_email('<email_address>', 'Message Subject', 'Message Body').deliver_now
   ```

Si vous ne parvenez pas à envoyer des e-mails, consultez la [section de dépannage SMTP](https://docs.gitlab.com/omnibus/settings/smtp/#troubleshooting).

#### Exiger la vérification par e-mail pour les comptes verrouillés {#require-email-verification-for-locked-accounts}

La vérification par e-mail du compte offre une couche de sécurité supplémentaire pour les comptes GitLab. Lorsque certaines conditions sont remplies, par exemple en cas de trois tentatives de connexion échouées ou plus en 24 heures, un compte est verrouillé.

Prérequis :

- Vous devez être administrateur.

Pour exiger la vérification par e-mail pour les comptes verrouillés :

1. Dans le coin supérieur droit, sélectionnez **Admin**.
1. Dans la barre latérale gauche, sélectionnez **Paramètres** > **Généralités**.
1. Développez **Restrictions de connexion**.
1. Cochez la case **Vérification par courriel des comptes verrouillés**.
1. Sélectionnez **Enregistrer les modifications**.

Pour plus d'informations, consultez la documentation sur la [vérification par e-mail des comptes](../../security/email_verification.md).

#### Signer les e-mails sortants avec S/MIME {#sign-outgoing-email-with-smime}

Les e-mails de notification envoyés par GitLab peuvent être signés avec [S/MIME](https://en.wikipedia.org/wiki/S/MIME) pour une sécurité renforcée.

Une seule paire de fichiers de clé et de certificat doit être fournie :

- Les deux fichiers doivent être encodés en PEM.
- Le fichier de clé doit être non chiffré afin que GitLab puisse le lire sans intervention de l'utilisateur.
- Seules les clés RSA sont prises en charge.
- Facultatif. Vous pouvez fournir un ensemble de certificats d'autorité de certification (CA) (encodés en PEM) à inclure dans chaque signature. Il s'agit généralement d'une CA intermédiaire.

1. Achetez votre certificat auprès d'une CA.
1. Modifiez `/etc/gitlab/gitlab.rb` et adaptez les chemins de fichiers :

   ```ruby
   gitlab_rails['gitlab_email_smime_enabled'] = true
   gitlab_rails['gitlab_email_smime_key_file'] = '/etc/gitlab/ssl/gitlab_smime.key'
   gitlab_rails['gitlab_email_smime_cert_file'] = '/etc/gitlab/ssl/gitlab_smime.crt'
   ```

1. Enregistrez le fichier et reconfigurez GitLab :

   ```shell
   sudo gitlab-ctl reconfigure
   ```

Pour plus d'informations, consultez la documentation sur la [signature des e-mails sortants avec S/MIME](../../administration/smime_signing_email.md).

## Étapes suivantes {#next-steps}

Dans ce tutoriel, vous avez appris à configurer votre serveur pour le rendre plus sécurisé, à installer GitLab et à configurer GitLab pour répondre à certaines normes de sécurité. Parmi les [autres étapes](../../security/hardening_application_recommendations.md) que vous pouvez effectuer pour sécuriser GitLab, citons :

- Désactiver les nouveaux comptes utilisateurs. Par défaut, une nouvelle instance GitLab a les nouveaux comptes utilisateurs activés. Si vous ne prévoyez pas de rendre votre instance GitLab publique, vous devriez désactiver les nouveaux comptes utilisateurs.
- Autoriser ou refuser les nouveaux comptes utilisateurs en fonction de domaines de messagerie spécifiques.
- Définir une longueur minimale de mot de passe pour les nouveaux utilisateurs.
- Imposer l'authentification à deux facteurs pour tous les utilisateurs.

Il existe de nombreuses autres choses que vous pouvez configurer en dehors du renforcement de votre instance GitLab, comme la configuration de vos propres runners pour exploiter les fonctionnalités CI/CD que GitLab propose, ou la sauvegarde correcte de votre instance.

Vous pouvez en savoir plus sur les [étapes à suivre après l'installation](../../install/next_steps.md).
