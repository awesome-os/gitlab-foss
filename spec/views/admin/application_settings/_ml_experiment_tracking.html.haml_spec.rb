# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/_ml_experiment_tracking.html.haml', feature_category: :mlops do
  let(:app_settings) { ApplicationSetting.create_from_defaults }

  before do
    assign(:application_setting, app_settings)
  end

  it 'renders the retention period without a deletion date while retention is off' do
    render

    expect(rendered).to have_field('application_setting_ml_experiment_tracking_run_retention_days', with: '0')
    expect(rendered).to have_no_text('Deletion starts on')
  end

  context 'when retention is on' do
    before do
      travel_to(Time.zone.parse('2026-11-13 10:00:00')) do
        app_settings.update!(ml_experiment_tracking_run_retention_days: 730)
      end
    end

    it 'renders the first deletion date, one period after retention was turned on' do
      render

      expect(rendered).to have_field('application_setting_ml_experiment_tracking_run_retention_days', with: '730')
      expect(rendered).to have_text('Deletion starts on November 12, 2028 at the earliest.')
    end

    it 'renders the saved deletion date after a rejected change' do
      app_settings.ml_experiment_tracking_run_retention_days = 36_501
      app_settings.validate

      render

      expect(rendered).to have_text('Deletion starts on November 12, 2028 at the earliest.')
    end
  end
end
