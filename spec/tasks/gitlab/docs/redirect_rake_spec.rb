# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe 'gitlab:docs:redirect', :silence_stdout, time_travel_to: Time.utc(2026, 1, 15, 12), feature_category: :gitlab_docs do
  let(:dir) { Dir.mktmpdir }
  let(:old_path) { File.join(dir, 'doc/old/page.md') }

  before do
    Rake.application.rake_require 'tasks/gitlab/docs/redirect'
    FileUtils.mkdir_p(File.dirname(old_path))
  end

  after do
    FileUtils.rm_rf(dir)
  end

  def redirect
    File.read(old_path)
  end

  it 'writes a relative redirect that expires in three months' do
    run_rake_task('gitlab:docs:redirect', old_path, File.join(dir, 'doc/new/page.md'))

    expect(redirect).to include("redirect_to: '../new/page.md'", "remove_date: '2026-04-15'")
  end

  it 'writes an external redirect that expires in one year' do
    run_rake_task('gitlab:docs:redirect', old_path, 'https://docs.gitlab.com/page/')

    expect(redirect).to include("redirect_to: 'https://docs.gitlab.com/page/'", "remove_date: '2027-01-15'")
  end

  it 'asks for the paths when they are not given' do
    allow($stdin).to receive(:gets).and_return("#{old_path}\n", "https://docs.gitlab.com/page/\n")

    run_rake_task('gitlab:docs:redirect')

    expect(redirect).to include("redirect_to: 'https://docs.gitlab.com/page/'")
  end
end
