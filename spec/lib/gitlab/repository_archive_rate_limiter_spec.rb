# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::RepositoryArchiveRateLimiter, feature_category: :source_code_management do
  let(:described_class) do
    Class.new do
      include ::Gitlab::RepositoryArchiveRateLimiter

      attr_reader :request

      def initialize(request)
        @request = request
      end

      def check_rate_limit!(**args); end
    end
  end

  let(:request) { instance_double(ActionDispatch::Request, ip: '1.2.3.4') }

  subject { described_class.new(request) }

  describe "#archive_rate_limit_reached?" do
    let(:project) { instance_double(Project) }
    let(:current_user) { instance_double(User) }
    let(:check) { subject.archive_rate_limit_reached?(current_user, project) }

    context 'when archive_rate_limit feature flag is disabled' do
      before do
        stub_feature_flags(archive_rate_limit: false)
      end

      it 'returns false' do
        expect(check).to be false
      end
    end

    context 'when archive_rate_limit feature flag is enabled' do
      before do
        stub_feature_flags(archive_rate_limit: true)
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_return(false)
      end

      context 'when current user exists' do
        it 'peeks the cross-project limit by user' do
          expect(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?)
            .with(request, current_user, :repositories_archive,
              scope: { user: current_user }, peek: true)
            .and_return(false)

          check
        end

        it 'peeks the per-project limit' do
          expect(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?)
            .with(request, current_user, :project_repositories_archive,
              scope: { project: project, user: current_user }, threshold: nil, peek: true)
            .and_return(false)

          check
        end

        it 'returns true when the cross-project limit is reached' do
          allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?)
            .with(request, current_user, :repositories_archive, anything)
            .and_return(true)

          expect(check).to be true
        end

        it 'returns true when the per-project limit is reached' do
          allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?)
            .with(request, current_user, :project_repositories_archive, anything)
            .and_return(true)

          expect(check).to be true
        end
      end

      context 'when current user does not exist' do
        let(:current_user) { nil }

        it 'peeks the cross-project limit by IP' do
          expect(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?)
            .with(request, nil, :repositories_archive_unauthenticated,
              scope: { ip: '1.2.3.4' }, peek: true)
            .and_return(false)

          check
        end

        it 'peeks the per-project limit with threshold 100' do
          expect(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?)
            .with(request, nil, :project_repositories_archive,
              scope: { project: project, user: nil }, threshold: 100, peek: true)
            .and_return(false)

          check
        end
      end
    end
  end

  describe "#check_archive_rate_limit!" do
    let(:project) { instance_double(Project) }
    let(:current_user) { instance_double(User) }
    let(:check) { subject.check_archive_rate_limit!(current_user, project) }

    context 'when archive_rate_limit feature flag is disabled' do
      before do
        stub_feature_flags(archive_rate_limit: false)
      end

      it 'does not check rate limit' do
        expect(subject).not_to receive(:check_rate_limit!)

        expect(check).to be_nil
      end
    end

    context 'when archive_rate_limit feature flag is enabled' do
      before do
        stub_feature_flags(archive_rate_limit: true)
      end

      context 'when current user exists' do
        it 'checks the cross-project limit by user' do
          expect(subject).to receive(:check_rate_limit!)
            .with(:repositories_archive, scope: { user: current_user })
            .ordered

          expect(subject).to receive(:check_rate_limit!)
            .with(:project_repositories_archive,
              scope: { project: project, user: current_user }, threshold: nil)
            .ordered

          check
        end

        context 'when cross-project limit renders a response' do
          let(:performed) { true }

          let(:described_class) do
            Class.new do
              include ::Gitlab::RepositoryArchiveRateLimiter

              attr_reader :request

              def initialize(request, performed)
                @request = request
                @performed = performed
              end

              def performed?
                @performed
              end

              def check_rate_limit!(**args); end
            end
          end

          subject { described_class.new(request, performed) }

          it 'does not check the per-project limit' do
            allow(subject).to receive(:check_rate_limit!)

            check

            expect(subject).to have_received(:check_rate_limit!)
              .with(:repositories_archive, scope: { user: current_user })
            expect(subject).not_to have_received(:check_rate_limit!)
              .with(:project_repositories_archive, anything)
          end
        end
      end

      context 'when current user does not exist' do
        let(:current_user) { nil }

        it 'checks the cross-project limit by IP' do
          expect(subject).to receive(:check_rate_limit!)
            .with(:repositories_archive_unauthenticated, scope: { ip: '1.2.3.4' })
            .ordered

          expect(subject).to receive(:check_rate_limit!)
            .with(:project_repositories_archive,
              scope: { project: project, user: nil }, threshold: 100)
            .ordered

          check
        end
      end
    end
  end
end
