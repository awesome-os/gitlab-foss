# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GracefulTimeoutHandling, feature_category: :value_stream_management do
  let(:log_payload) { {} }

  controller(ApplicationController) do
    include GracefulTimeoutHandling

    skip_before_action :authenticate_user!

    def index
      raise ActiveRecord::QueryCanceled
    end

    def show
      render json: {}
    end
  end

  before do
    allow(controller).to receive(:append_info_to_payload).and_wrap_original do |method, payload|
      method.call(payload)
      log_payload.merge!(payload)
    end
  end

  context 'for json request' do
    subject { get :index, format: :json }

    it 'renders graceful error message' do
      subject

      expect(json_response['error']).to eq(_('There is too much data to calculate. Please change your selection.'))
      expect(response.code).to eq '200'
    end

    it 'logs exception' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(kind_of(ActiveRecord::QueryCanceled))

      subject
    end

    it 'flags the timeout in the request log payload' do
      subject

      expect(log_payload[:metadata]).to include('meta.graceful_timeout' => true)
    end
  end

  context 'for a request that does not time out' do
    subject { get :show, params: { id: 1 }, format: :json }

    it 'does not flag the request log payload' do
      subject

      expect(log_payload[:metadata].to_h).not_to include('meta.graceful_timeout')
    end
  end

  context 'for html request' do
    subject { get :index, format: :html }

    it 'has no effect' do
      expect do
        subject
      end.to raise_error(ActiveRecord::QueryCanceled)
    end
  end
end
