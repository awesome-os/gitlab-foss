# frozen_string_literal: true

RSpec.shared_examples 'with rapid_diffs_diff_blobs enabled' do
  context 'with rapid_diffs_diff_blobs enabled' do
    before do
      stub_feature_flags(rapid_diffs_diff_blobs: true)
      allow(Gitlab::GitalyClient).to receive(:call).and_call_original
    end

    it 'fetches diffs with the DiffBlobs RPC' do
      go(w: '0')

      expect(Gitlab::GitalyClient).to have_received(:call)
        .with(anything, :diff_service, :diff_blobs, any_args).at_least(:once)
    end

    context 'when hiding whitespace changes' do
      it 'falls back to the diff collection' do
        go(w: '1')

        expect(response).to have_gitlab_http_status(:success)
        expect(response.body).to include(*diff_files.to_a.map(&:file_hash))
        expect(Gitlab::GitalyClient).not_to have_received(:call).with(anything, :diff_service, :diff_blobs, any_args)
      end
    end

    context 'when offset is not given' do
      it 'streams all diffs' do
        go(w: '0')

        expect(response).to have_gitlab_http_status(:success)
        expect(response.body).to include(*diff_files.to_a.map(&:file_hash))
      end

      it 'streams diffs in the same order as the diff files' do
        go(w: '0')

        streamed_file_hashes = Nokogiri::HTML(response.body).css('diff-file').pluck('id')

        expect(streamed_file_hashes).to eq(diff_files.to_a.map(&:file_hash))
      end
    end

    context 'when offset is given' do
      let(:offset) { 1 }

      it 'streams diffs except the offset' do
        go(w: '0', offset: offset)

        offset_file_identifier_hashes = diff_files.to_a.take(offset).map(&:file_hash)
        remaining_file_identifier_hashes = diff_files.to_a.slice(offset..).map(&:file_hash)

        expect(response).to have_gitlab_http_status(:success)
        expect(response.body).not_to include(*offset_file_identifier_hashes)
        expect(response.body).to include(*remaining_file_identifier_hashes)
      end
    end
  end

  def file_identifier_hashes(diff)
    diff.diffs.diff_files.to_a.map(&:file_hash)
  end
end
