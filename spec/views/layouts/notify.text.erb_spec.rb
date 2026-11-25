# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'layouts/notify.text.erb', feature_category: :notifications do
  let(:target_url) { 'https://gitlab.example.com/group/project/-/issues/1' }

  before do
    assign(:target_url, target_url)
  end

  context 'when replying by email is not possible' do
    it 'shows the link to GitLab' do
      render template: 'layouts/notify', formats: [:text]

      expect(rendered).to include(format(s_('Notify|View it on GitLab: %{url}'), url: target_url))
    end

    it 'translates the link text' do
      allow(view).to receive(:s_).and_call_original
      allow(view).to receive(:s_).with('Notify|View it on GitLab: %{url}').and_return('Voir sur GitLab : %{url}')

      render template: 'layouts/notify', formats: [:text]

      expect(rendered).to include("Voir sur GitLab : #{target_url}")
    end
  end

  context 'when replying by email is possible' do
    before do
      assign(:reply_by_email, true)
    end

    it 'shows the reply hint with the link to GitLab' do
      render template: 'layouts/notify', formats: [:text]

      expect(rendered).to include(
        format(s_('Notify|Reply to this email directly or view it on GitLab: %{url}'), url: target_url)
      )
    end

    it 'translates the reply hint' do
      allow(view).to receive(:s_).and_call_original
      allow(view).to receive(:s_)
        .with('Notify|Reply to this email directly or view it on GitLab: %{url}')
        .and_return('Répondez à cet e-mail ou voyez-le sur GitLab : %{url}')

      render template: 'layouts/notify', formats: [:text]

      expect(rendered).to include("Répondez à cet e-mail ou voyez-le sur GitLab : #{target_url}")
    end
  end

  context 'when the note is on a diff and the project does not show diff previews in emails' do
    let(:discussion) { instance_double(DiffDiscussion, diff_discussion?: true, on_text?: true) }
    let(:note) { instance_double(DiffNote, part_of_discussion?: true, discussion: discussion) }
    let(:project) { instance_double(Project, show_diff_preview_in_email?: false) }

    before do
      assign(:note, note)
      assign(:project, project)
    end

    it 'shows the message about diff previews' do
      render template: 'layouts/notify', formats: [:text]

      expect(rendered).to include(_('This project does not include diff previews in email notifications.'))
    end

    it 'puts the message about diff previews on its own line' do
      render template: 'layouts/notify', formats: [:text]

      expect(rendered).to include(
        "#{_('This project does not include diff previews in email notifications.')}\n" \
          "#{format(s_('Notify|View it on GitLab: %{url}'), url: target_url)}"
      )
    end

    it 'translates the message about diff previews' do
      allow(view).to receive(:_).and_call_original
      allow(view).to receive(:_)
        .with('This project does not include diff previews in email notifications.')
        .and_return('Ce projet n’inclut pas les aperçus des diffs dans les e-mails.')

      render template: 'layouts/notify', formats: [:text]

      expect(rendered).to include('Ce projet n’inclut pas les aperçus des diffs dans les e-mails.')
    end
  end
end
