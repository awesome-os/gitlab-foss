---
title: GitLab Runner 19.6
tier: [ Free, Premium, Ultimate ]
offering: [ gitlab_com, self_managed, gitlab_dedicated, gitlab_dedicated_for_government ]
stage: verify
documentation_link: https://docs.gitlab.com/runner
work_item: https://gitlab.com/gitlab-org/gitlab-runner/-/issues/?milestone_title=19.6&state=closed
categories: [ GitLab Runner Core ]
level: secondary
---

本日、GitLab Runner 19.6もリリースします。GitLab Runnerは、CI/CDジョブを実行してその結果をGitLabインスタンスに送信する、高いスケーラビリティを持つビルドエージェントです。GitLab RunnerはGitLab CI/CDと連携して動作します。GitLab CI/CDは、GitLabに含まれるオープンソースの継続的インテグレーションサービスです。

**新機能**

- [GitLab.comにおいて、Job Routerが内部リレーアドレスを使用するようになり、相関IDの発生元を記録するようになりました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39944)
- [GitLab Runnerの`[runners.artifact]`に`direct_download`設定が追加され、非推奨の`FF_USE_DIRECT_DOWNLOAD`機能フラグに代わるものとして提供されるようになりました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39682)
- [GitLab RunnerがUbuntu 26.04（Resolute）向けのネイティブパッケージを提供するようになりました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39449)
- [GitLab RunnerがGitLab APIリクエストにHTTP/2を使用できるようになりました。HTTP/2はデフォルトでは無効です。有効にするには、`allow_http2`を`true`に設定してください。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/28862)
- [Kubernetesエグゼキューターのポーズポッドがラベルとアノテーションをサポートするようになりました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39844)また、[ジョブポッドと同じノードアフィニティおよびスケジューラーを使用するようになり、キャパシティが利用可能な場合にのみジョブをリクエストする実験的な`preemptive_mode`も追加されました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39615)
- [Kubernetesエグゼキューターのジョブログに使用中のヘルパーイメージが表示されるようになりました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/2387)
- [ジョブログのビルドセクションの折りたたみを切り替えられるようになりました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/38932)

**バグ修正**

- [コミュニティフォークのパイプラインが`gitlab_secrets_manager source group with path 'gitlab-org' not found`で失敗する問題を修正しました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/40099)
- [registerフラグ`--docker-pull-policy`の動作が変更され、他のフラグと一貫性がなくなっていた問題を修正しました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/40013)
- [`FF_CONCRETE`ジョブが設定済みのシェルを使用するようになりました。`shell = "sh"`を使用しているジョブで、配列や`[[ ]]`などのbash専用の構文を使用している場合、失敗する可能性があります。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39955)
- [Docker Autoscalerがv19.3.1においてトークンローテーションとは無関係に、ジョブの実行中にアクティブなインスタンスを削除してしまう問題を修正しました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39811)
- [Runnerが制御するソースフェッチの失敗とユーザースクリプトの失敗を区別できるようになりました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39695)
- [`FF_USE_GIT_NATIVE_CLONE`がパイプラインのSHAではなく、変更可能なマージリクエストのマージ参照をクローンするため、ターゲットブランチが進んだ際にマージ結果パイプラインが壊れる問題を修正しました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39641)
- [PodmanランタイムのDockerエグゼキューターにおいて、seccompプロファイルパスがインラインJSONに書き換えられ、GitLab Runner 19.xで`file name too long`エラーが発生する問題を修正しました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39496)
- [`FF_NETWORK_PER_BUILD`が有効な場合に、Docker Autoscalerが終了済みインスタンスのネットワークを削除できずジョブが失敗する問題を修正しました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39145)
- [マスクされていない`/proc`マウントを使用するジョブがKubernetesエグゼキューターで失敗しなくなりました。Runnerがこれらのジョブに対してユーザーネームスペースを有効にするようになりました。これはKubernetesがマスクされていないマウントに必要とするものです。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39399)
- [グレースフルシャットダウン（`SIGQUIT`）が実行中のジョブおよびジョブリクエストをキャンセルし、GitLabがすでに割り当てたジョブが孤立する問題を修正しました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39847)
- [`FF_USE_PARALLEL_CACHE_TRANSFER`または`FF_USE_PARALLEL_ARTIFACT_TRANSFER`が有効な場合に、サーバーまたはプロキシが`Range`リクエストを無視すると、キャッシュおよびアーティファクトのダウンロードでファイルが静かに破損する問題を修正しました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/40102)
- [ネストされたサブモジュールが削除され、`GIT_STRATEGY`が`fetch`の場合にGitLab Runnerが失敗する問題を修正しました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/38871)
- [Kubernetesエグゼキューターのイメージプルリトライが`pod is being deleted`でジョブを失敗させる問題を修正しました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39817)
- [`FF_KUBERNETES_HONOR_ENTRYPOINT=true`の場合に、Kubernetesエグゼキューターがサービスコマンドを無視する問題](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/40237)と、[UTC以外のタイムゾーンのノードでジョブログが重複する問題](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39470)を修正しました。
- [パイプラインで機能フラグを設定すると、Kubernetesポッドで環境変数が重複する問題を修正しました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/36893)
- [DockerエグゼキューターにおいてイメージがENTRYPOINTを設定している場合に、`umask`のないRunnerの`id -u`チェックが失敗する問題を修正しました。](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/40014)

すべての変更点の一覧は、GitLab RunnerのChangelog（[CHANGELOG](https://gitlab.com/gitlab-org/gitlab-runner/blob/19-6-stable/CHANGELOG.md)）をご覧ください。
