# frozen_string_literal: true

require 'spec_helper'

# Snippet visibility scenarios are included in more details in spec/support/snippet_visibility.rb
RSpec.describe PersonalSnippetPolicy do
  let(:regular_user) { create(:user) }
  let(:external_user) { create(:user, :external) }
  let(:admin_user) { create(:user, :admin) }

  let(:author_permissions) do
    [
      :update_snippet,
      :delete_snippet
    ]
  end

  def permissions(user)
    described_class.new(user, snippet)
  end

  shared_examples 'admin access with admin mode' do
    context 'admin user', :enable_admin_mode do
      subject { permissions(admin_user) }

      it 'allows reading, creating notes, awarding emoji, and author permissions' do
        expect_allowed(:read_snippet)
        expect_allowed(:create_note)
        expect_allowed(:award_emoji)
        expect_allowed(*author_permissions)
      end
    end
  end

  context 'public snippet' do
    let(:snippet) { create(:personal_snippet, :public) }

    context 'no user' do
      subject { permissions(nil) }

      it 'allows reading and caching the blob but not creating notes, awarding emoji, or author permissions' do
        expect_allowed(:read_snippet)
        expect_allowed(:cache_blob)
        expect_disallowed(:create_note)
        expect_disallowed(:award_emoji)
        expect_disallowed(*author_permissions)
      end
    end

    context 'regular user' do
      subject { permissions(regular_user) }

      it 'allows reading, creating notes, and awarding emoji but not author permissions' do
        expect_allowed(:read_snippet)
        expect_allowed(:create_note)
        expect_allowed(:award_emoji)
        expect_disallowed(*author_permissions)
      end
    end

    context 'author' do
      subject { permissions(snippet.author) }

      it 'allows reading, creating notes, awarding emoji, and author permissions' do
        expect_allowed(:read_snippet)
        expect_allowed(:create_note)
        expect_allowed(:award_emoji)
        expect_allowed(*author_permissions)
      end
    end

    it_behaves_like 'admin access with admin mode'
  end

  context 'internal snippet' do
    let(:snippet) { create(:personal_snippet, :internal) }

    context 'no user' do
      subject { permissions(nil) }

      it 'disallows reading, creating notes, awarding emoji, and author permissions' do
        expect_disallowed(:read_snippet)
        expect_disallowed(:create_note)
        expect_disallowed(:award_emoji)
        expect_disallowed(*author_permissions)
      end
    end

    context 'regular user' do
      subject { permissions(regular_user) }

      it 'allows reading, creating notes, and awarding emoji but not author permissions' do
        expect_allowed(:read_snippet)
        expect_allowed(:create_note)
        expect_allowed(:award_emoji)
        expect_disallowed(*author_permissions)
      end
    end

    context 'external user' do
      subject { permissions(external_user) }

      it 'disallows reading, creating notes, awarding emoji, and author permissions' do
        expect_disallowed(:read_snippet)
        expect_disallowed(:create_note)
        expect_disallowed(:award_emoji)
        expect_disallowed(*author_permissions)
      end
    end

    context 'snippet author' do
      subject { permissions(snippet.author) }

      it 'allows reading, creating notes, awarding emoji, and author permissions' do
        expect_allowed(:read_snippet)
        expect_allowed(:create_note)
        expect_allowed(:award_emoji)
        expect_allowed(*author_permissions)
      end
    end

    it_behaves_like 'admin access with admin mode'
  end

  context 'private snippet' do
    let(:snippet) { create(:project_snippet, :private) }

    context 'no user' do
      subject { permissions(nil) }

      it 'disallows reading, caching the blob, creating notes, awarding emoji, and author permissions' do
        expect_disallowed(:read_snippet)
        expect_disallowed(:create_note)
        expect_disallowed(:award_emoji)
        expect_disallowed(:cache_blob)
        expect_disallowed(*author_permissions)
      end
    end

    context 'regular user' do
      subject { permissions(regular_user) }

      it 'disallows reading, creating notes, awarding emoji, and author permissions' do
        expect_disallowed(:read_snippet)
        expect_disallowed(:create_note)
        expect_disallowed(:award_emoji)
        expect_disallowed(*author_permissions)
      end
    end

    context 'external user' do
      subject { permissions(external_user) }

      it 'disallows reading, creating notes, awarding emoji, and author permissions' do
        expect_disallowed(:read_snippet)
        expect_disallowed(:create_note)
        expect_disallowed(:award_emoji)
        expect_disallowed(*author_permissions)
      end
    end

    context 'snippet author' do
      subject { permissions(snippet.author) }

      it 'allows reading, creating notes, awarding emoji, and author permissions' do
        expect_allowed(:read_snippet)
        expect_allowed(:create_note)
        expect_allowed(:award_emoji)
        expect_allowed(*author_permissions)
      end
    end

    it_behaves_like 'admin access with admin mode'
  end

  context 'when the author of the snippet is banned', feature_category: :insider_threat do
    let(:banned_user) { build(:user, :banned) }
    let(:snippet) { build(:personal_snippet, :public, author: banned_user) }

    context 'no user' do
      subject { permissions(nil) }

      it 'disallows reading, creating notes, awarding emoji, and author permissions' do
        expect_disallowed(:read_snippet)
        expect_disallowed(:create_note)
        expect_disallowed(:award_emoji)
        expect_disallowed(*author_permissions)
      end
    end

    context 'regular user' do
      subject { permissions(regular_user) }

      it 'disallows reading the snippet and its notes, creating notes, and author permissions' do
        expect_disallowed(:read_snippet)
        expect_disallowed(:read_note)
        expect_disallowed(:create_note)
        expect_disallowed(*author_permissions)
      end
    end

    context 'external user' do
      subject { permissions(external_user) }

      it 'disallows reading the snippet and its notes, creating notes, and author permissions' do
        expect_disallowed(:read_snippet)
        expect_disallowed(:read_note)
        expect_disallowed(:create_note)
        expect_disallowed(*author_permissions)
      end
    end

    context 'snippet author' do
      subject { permissions(snippet.author) }

      it 'disallows reading the snippet and its notes, creating notes, and author permissions' do
        expect_disallowed(:read_snippet)
        expect_disallowed(:read_note)
        expect_disallowed(:create_note)
        expect_disallowed(*author_permissions)
      end
    end

    it_behaves_like 'admin access with admin mode'
  end
end
