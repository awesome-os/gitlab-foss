# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/commit/_commit_box.html.haml' do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, developers: user) }

  let(:commit) { project.commit }

  before do
    assign(:project, project)
    assign(:commit, commit)
    allow(view).to receive_messages(current_user: user, can_collaborate_with_project?: false)
  end

  it 'shows the commit SHA' do
    render

    expect(rendered).to have_text(Commit.truncate_sha(project.commit.sha).to_s)
  end

  context 'when there is a pipeline present' do
    let(:pipeline) { create(:ci_pipeline, project: project, sha: project.commit.id, status: 'success') }

    context 'when pipeline has stages' do
      before do
        create(:ci_build, pipeline: pipeline, ci_stage: create(:ci_stage, name: 'build', pipeline: pipeline))

        assign(:last_pipeline, project.commit.last_pipeline)
      end

      it 'shows pipeline stages in vue' do
        render

        expect(rendered).to have_selector("#js-commit-box-pipeline-summary[data-iid='#{pipeline.iid}']")
      end
    end

    context 'when pipeline has no iid' do
      before do
        pipeline.update_column(:iid, nil)

        assign(:last_pipeline, pipeline)
      end

      it 'does not show the pipeline summary' do
        render

        expect(rendered).not_to have_selector('#js-commit-box-pipeline-summary')
      end
    end
  end

  context 'in the context of a merge request' do
    let(:merge_request) { build_stubbed(:merge_request, source_project: project, target_project: project) }

    before do
      assign(:merge_request, merge_request)
      render
    end

    it 'shows that it is in the context of a merge request' do
      merge_request_url = diffs_project_merge_request_path(project, merge_request, commit_id: commit.id)
      expect(rendered).to have_content("This commit is part of merge request")
      expect(rendered).to have_link(merge_request.to_reference, href: merge_request_url)
    end

    context 'when merge request is nil' do
      let(:merge_request) { nil }

      it 'does not show the merge request context' do
        expect(rendered).not_to have_content("This commit is part of merge request")
      end
    end
  end

  context 'when commit is signed' do
    let(:page) { Nokogiri::HTML.parse(rendered) }
    let(:badge) { page.at('.signature-badge') }
    let(:badge_attributes) { badge.attributes }
    let(:title) { badge_attributes['data-title'].value }
    let(:content) { badge_attributes['data-content'].value }

    context 'with GPG' do
      let(:commit) { project.commit(GpgHelpers::SIGNED_COMMIT_SHA) }

      it 'renders unverified badge' do
        render

        expect(title).to include('This commit was signed with an unverified signature.')
        expect(content).to include(commit.signature.gpg_key_primary_keyid)
      end

      context 'when the committer email is a confirmed secondary email of the key owner' do
        before do
          key_owner = create(:user, email: GpgHelpers::User2.emails.first)
          create(:email, :confirmed, user: key_owner, email: commit.committer_email)
          create(:gpg_key, key: GpgHelpers::User2.public_key, user: key_owner)

          # The confirmed email makes key_owner the commit author, whose status the controller preloads
          allow(view).to receive(:user_status)
        end

        it 'renders signature key mismatch badge' do
          render

          expect(title).to include('Signature key mismatch')
          expect(title).to include(
            'This commit was signed with a verified signature, but the committer email is not verified.'
          )
          expect(content).to include(GpgHelpers::User2.primary_keyid)
        end
      end
    end

    context 'with SSH' do
      let(:commit) { project.commit('7b5160f9bb23a3d58a0accdbe89da13b96b1ece9') }

      it 'renders unverified badge' do
        render

        expect(title).to include('This commit was signed with an unverified signature.')
        expect(content).to match(/SSH key fingerprint:[\s\S].+#{commit.signature.key_fingerprint_sha256}/)
      end

      context 'when the commit has been signed by GitLab' do
        it 'renders verified badge' do
          allow_next_instance_of(Gitlab::Ssh::Commit) do |instance|
            allow(instance).to receive(:signer).and_return(:SIGNER_SYSTEM)
          end

          render

          expect(content).to match(/SSH key fingerprint:[\s\S].+#{commit.signature.key_fingerprint_sha256}/)
          expect(title).to include(
            'This commit was created in the GitLab UI, and signed with a GitLab-verified signature.'
          )
        end
      end

      context 'when the signing key was revoked' do
        let(:key) { create(:key, user: user) }

        before do
          create(
            :ssh_signature,
            project: project,
            commit_sha: commit.sha,
            key: key,
            key_fingerprint_sha256: key.fingerprint_sha256,
            verification_status: :revoked_key
          )
        end

        it 'renders revoked key badge' do
          render

          expect(title).to include('Unverified signature')
          expect(title).to include('This commit was signed with a key that was revoked.')
          expect(content).to match(/SSH key fingerprint:[\s\S].+#{Regexp.escape(key.fingerprint_sha256)}/)
        end
      end
    end

    context 'with X.509' do
      let(:commit) { project.commit('189a6c924013fc3fe40d6f1ec1dc20214183bc97') }

      it 'renders unverified badge' do
        render

        expect(title).to include('This commit was signed with an <strong>unverified</strong> signature.')
        expect(content).to include(commit.signature.x509_certificate.subject_key_identifier.tr(":", " "))
      end
    end
  end
end
