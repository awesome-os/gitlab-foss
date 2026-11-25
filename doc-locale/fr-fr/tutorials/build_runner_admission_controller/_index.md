---
stage: Verify
group: Runner Core
info: For assistance with this tutorial, see <https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments-to-other-projects-and-subjects>.
title: 'Tutoriel : créer un contrôleur d''admission de runner'
---

<!-- vale gitlab_base.FutureTense = NO -->

Ce tutoriel vous guide dans la création d'un contrôleur d'admission de runner qui applique des politiques personnalisées pour l'exécution des jobs CI/CD. Vous allez créer un contrôleur en Go qui se connecte au routeur de jobs et implémente une politique d'allowlist d'images.

Les exemples de code de ce tutoriel sont adaptés du dépôt [runner-controller-example](https://gitlab.com/gitlab-org/cluster-integration/runner-controller-example), qui fournit une implémentation de référence complète que vous pouvez utiliser comme point de départ.

À la fin de ce tutoriel, vous disposerez d'un contrôleur d'admission fonctionnel qui :

- Se connecte au routeur de jobs via gRPC
- S'enregistre auprès de GitLab
- Reçoit les demandes d'admission de jobs
- Évalue les jobs par rapport à une politique personnalisée
- Retourne les décisions d'admission

Pour créer un contrôleur d'admission de runner :

1. [Créer un contrôleur de runner dans GitLab](#create-a-runner-controller-in-gitlab)
1. [Définir la portée du contrôleur de runner](#scope-the-runner-controller)
1. [Créer un jeton de contrôleur de runner](#create-a-runner-controller-token)
1. [Configurer votre projet Go](#set-up-your-go-project)
1. [Générer le code client à partir des définitions protobuf](#generate-client-code-from-protobuf-definitions)
1. [Implémenter l'authentification](#implement-authentication)
1. [Implémenter l'enregistrement de l'agent](#implement-agent-registration)
1. [Implémenter la boucle d'admission](#implement-the-admission-loop)
1. [Implémenter une politique d'admission](#implement-an-admission-policy)
1. [Tester avec l'état dry run](#test-with-dry-run-state)
1. [Activer en production](#enable-in-production)

## Avant de commencer {#before-you-begin}

Assurez-vous de disposer des éléments suivants :

- GitLab Self-Managed ou GitLab Dedicated avec l'édition Ultimate
- Accès administrateur à votre instance GitLab
- L'un des éléments suivants pour interagir avec l'API GitLab :
  - [GitLab CLI (`glab`)](https://docs.gitlab.com/cli/) 1.85.0 ou version ultérieure, authentifié avec `glab auth login`
  - `curl` ou un autre client HTTP
- Go 1.21 ou version ultérieure installé
- [Le CLI `buf`](https://buf.build/docs/installation/) installé pour générer le code Protobuf
- Les feature flags suivants activés sur votre instance GitLab :
  - `job_router`
  - `job_router_admission_control`
- GitLab Runner 18.9 ou version ultérieure avec la variable d'environnement `FF_USE_JOB_ROUTER` définie sur `true`.

## Créer un contrôleur de runner dans GitLab {#create-a-runner-controller-in-gitlab}

Utilisez l'[API des contrôleurs de runner](../../api/runner_controllers.md) pour créer un contrôleur de runner.

Commencez avec l'état `dry_run` pour valider le comportement de votre contrôleur avant d'activer l'application des politiques :

{{< tabs >}}

{{< tab title="GitLab CLI" >}}

```shell
glab runner-controller create --description "Image allowlist controller" --state dry_run
```

{{< /tab >}}

{{< tab title="curl" >}}

```shell
curl --request POST \
     --header "PRIVATE-TOKEN: <your_access_token>" \
     --header "Content-Type: application/json" \
     --data '{"description": "Image allowlist controller", "state": "dry_run"}' \
     --url "https://gitlab.example.com/api/v4/runner_controllers"
```

{{< /tab >}}

{{< /tabs >}}

Enregistrez la valeur `id` retournée pour l'étape suivante.

## Définir la portée du contrôleur de runner {#scope-the-runner-controller}

Les contrôleurs de runner doivent avoir une portée définie pour recevoir les demandes d'admission. Sans portée définie, votre contrôleur reste inactif même lorsqu'il est activé.

Pour ce tutoriel, définissez la portée du contrôleur sur tous les runners de l'instance :

{{< tabs >}}

{{< tab title="GitLab CLI" >}}

```shell
glab runner-controller scope create <controller_id> --instance
```

{{< /tab >}}

{{< tab title="curl" >}}

```shell
curl --request POST \
     --header "PRIVATE-TOKEN: <your_access_token>" \
     --url "https://gitlab.example.com/api/v4/runner_controllers/<controller_id>/scopes/instance"
```

{{< /tab >}}

{{< /tabs >}}

Vous pouvez également définir la portée du contrôleur sur des runners spécifiques en utilisant l'[API des contrôleurs de runner](../../api/runner_controllers.md). Utilisez la portée au niveau du runner lorsque vous souhaitez que le contrôleur évalue les jobs uniquement pour certains runners.

## Créer un jeton de contrôleur de runner {#create-a-runner-controller-token}

Créez un jeton pour que votre contrôleur de runner s'authentifie auprès du routeur de jobs :

{{< tabs >}}

{{< tab title="GitLab CLI" >}}

```shell
glab runner-controller token create <controller_id> --description "Production token"
```

{{< /tab >}}

{{< tab title="curl" >}}

```shell
curl --request POST \
     --header "PRIVATE-TOKEN: <your_access_token>" \
     --header "Content-Type: application/json" \
     --data '{"description": "Production token"}' \
     --url "https://gitlab.example.com/api/v4/runner_controllers/<controller_id>/tokens"
```

{{< /tab >}}

{{< /tabs >}}

Enregistrez la valeur `token` retournée de manière sécurisée. Le jeton n'est affiché qu'une seule fois.

## Configurer votre projet Go {#set-up-your-go-project}

Créez un nouveau projet Go :

```shell
mkdir runner-admission-controller
cd runner-admission-controller
go mod init example.com/runner-admission-controller
```

## Générer le code client à partir des définitions protobuf {#generate-client-code-from-protobuf-definitions}

Vous devez générer le code client gRPC à partir des définitions Protobuf dans le dépôt [GitLab Agent for Kubernetes](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent). Vous pouvez utiliser n'importe quelle méthode de votre choix, notamment :

- Intégration manuelle des fichiers `.proto` et utilisation directe de `protoc`.
- Utilisation de [`buf`](https://buf.build/) pour récupérer et générer le code automatiquement.

Pour plus de détails sur les définitions Protobuf, consultez [la génération du code client](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/blob/master/doc/runner_controller.md#generating-client-code) dans la spécification du contrôleur de runner.

Ce tutoriel utilise `buf`. Créez `buf.gen.yaml` :

```yaml
version: v2

managed:
  enabled: true

  disable:
    - module: buf.build/bufbuild/protovalidate

  override:
    - file_option: go_package
      value: internal/rpc

inputs:
  - git_repo: https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent.git
    branch: master

plugins:
  - local: ["go", "run", "google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.10"]
    out: .
  - local: ["go", "run", "google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1"]
    out: .
```

Générez le code :

```shell
buf generate
```

Le code client gRPC est ainsi créé dans `internal/rpc/`.

## Implémenter l'authentification {#implement-authentication}

Les contrôleurs de runner s'authentifient auprès du routeur de jobs à l'aide des en-têtes de métadonnées gRPC. Pour plus de détails sur la spécification, consultez [Authentication](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/blob/master/doc/runner_controller.md#authentication) dans la spécification du contrôleur de runner.

Créez un fournisseur de credentials qui inclut les en-têtes requis :

```go
type tokenCredentials struct {
    token string
}

func (t *tokenCredentials) GetRequestMetadata(ctx context.Context, uri ...string) (map[string]string, error) {
    return map[string]string{
        "authorization":     "Bearer " + t.token,
        "gitlab-agent-type": "runnerc",
    }, nil
}

func (t *tokenCredentials) RequireTransportSecurity() bool {
    return true
}
```

Utilisez le code suivant pour créer la connexion gRPC :

```go
conn, err := grpc.NewClient(kasAddress,
    grpc.WithTransportCredentials(credentials.NewTLS(nil)),
    grpc.WithPerRPCCredentials(&tokenCredentials{token: agentToken}),
)
```

## Implémenter l'enregistrement de l'agent {#implement-agent-registration}

Enregistrez votre contrôleur auprès du routeur de jobs pour le suivi de présence et la supervision. Réenregistrez-vous périodiquement (recommandé : toutes les 3 minutes) pour maintenir la présence. Pour plus de détails sur la spécification, consultez [AgentRegistrar](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/blob/master/doc/runner_controller.md#agentregistrar) dans la spécification du contrôleur de runner.

```go
func registerAgent(ctx context.Context, conn *grpc.ClientConn, instanceID int64) error {
    client := rpc.NewAgentRegistrarClient(conn)

    _, err := client.Register(ctx, &rpc.RegisterRequest{
        Meta: &rpc.Meta{
            Version:      "1.0.0",
            GitRef:       "main",
            Architecture: runtime.GOARCH,
        },
        InstanceId: instanceID,
    })
    return err
}
```

## Implémenter la boucle d'admission {#implement-the-admission-loop}

La boucle d'admission reçoit les détails des jobs du routeur de jobs et envoie les décisions. Pour plus de détails sur la spécification, consultez [RunnerControllerService](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/blob/master/doc/runner_controller.md#runnercontrollerservice) et [Protocol Flow](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/blob/master/doc/runner_controller.md#protocol-flow) dans la spécification du contrôleur de runner.

```go
func handleAdmissionRequest(ctx context.Context, client rpc.RunnerControllerServiceClient) error {
    admissionCtx, cancel := context.WithCancel(ctx)
    defer cancel()

    stream, err := client.AdmitJob(admissionCtx)
    if err != nil {
        return err
    }

    // Wait for admission request
    req, err := stream.Recv()
    if err != nil {
        return err
    }

    // Evaluate the job (implement your policy here)
    admitted, reason := evaluateJob(req)

    // Send decision
    var resp *rpc.AdmitJobResponse
    if admitted {
        resp = &rpc.AdmitJobResponse{
            AdmissionResponse: &rpc.AdmitJobResponse_Admitted{Admitted: &rpc.Admitted{}},
        }
    } else {
        resp = &rpc.AdmitJobResponse{
            AdmissionResponse: &rpc.AdmitJobResponse_Rejected{
                Rejected: &rpc.Rejected{Reason: reason},
            },
        }
    }

    if err := stream.Send(resp); err != nil {
        return err
    }

    _ = stream.CloseSend()
    var x any
    err = stream.RecvMsg(x) // consume EOF
    if err != io.EOF {
      return err
    }

    return nil
}
```

## Implémenter une politique d'admission {#implement-an-admission-policy}

Implémentez votre logique de politique personnalisée. Cet exemple rejette les images portant le tag `:latest` :

```go
func evaluateJob(req *rpc.AdmitJobRequest) (admitted bool, reason string) {
    imageName := req.GetImage().GetName()

    // Reject :latest tags
    if strings.HasSuffix(imageName, ":latest") {
        return false, "images with :latest tag are not allowed"
    }

    // Check allowlist
    allowed := []string{"alpine", "ubuntu", "golang", "ruby", "node", "python"}
    for _, prefix := range allowed {
        if strings.HasPrefix(imageName, prefix) {
            return true, ""
        }
    }

    return false, fmt.Sprintf("image %s is not in the approved list", imageName)
}
```

## Tester avec l'état dry run {#test-with-dry-run-state}

Avec votre contrôleur en cours d'exécution et dans l'état `dry_run`, déclenchez un pipeline CI/CD. Vérifiez les logs de votre contrôleur pour confirmer qu'il reçoit bien les demandes d'admission. Le routeur de jobs enregistre les décisions, mais ne les applique pas pour les contrôleurs en état dry run. Cette action vous permet de valider le comportement et de réduire les risques liés à votre déploiement avant d'activer l'application des politiques.

## Activer en production {#enable-in-production}

Après avoir validé le comportement de votre contrôleur dans l'état `dry_run`, passez à l'état `enabled` :

{{< tabs >}}

{{< tab title="GitLab CLI" >}}

```shell
glab runner-controller update <controller_id> --state enabled
```

{{< /tab >}}

{{< tab title="curl" >}}

```shell
curl --request PUT \
     --header "PRIVATE-TOKEN: <your_access_token>" \
     --header "Content-Type: application/json" \
     --data '{"state": "enabled"}' \
     --url "https://gitlab.example.com/api/v4/runner_controllers/<controller_id>"
```

{{< /tab >}}

{{< /tabs >}}

Vos décisions d'admission affectent désormais l'exécution des jobs.

### Hébergement du contrôleur de runner {#hosting-the-runner-controller}

L'hébergement du contrôleur de runner dépend de vous, en fonction de l'échelle de l'instance GitLab et de la charge des jobs soumis au contrôle d'admission. La seule exigence est que l'instance GitLab soit accessible par le contrôleur de runner, car c'est à elle qu'il se connecte.

## Étapes suivantes {#next-steps}

- Consultez l'[implémentation d'exemple complète](https://gitlab.com/gitlab-org/cluster-integration/runner-controller-example).
- Lisez la [spécification du contrôleur de runner](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/blob/master/doc/runner_controller.md) pour obtenir des détails sur le protocole.
- Explorez l'utilisation de [Open Policy Agent (OPA)](https://www.openpolicyagent.org/) pour des politiques plus complexes.
