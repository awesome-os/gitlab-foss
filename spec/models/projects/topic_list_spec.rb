# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::TopicList, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:project) { create(:project) }

  describe '#names' do
    where(:value, :expected_names) do
      'topicA, topicB'           | %w[topicA topicB]
      ['topicA', ' topicB ', ''] | %w[topicA topicB]
      'topicA, , topicA'         | %w[topicA]
      'topicA, TOPICA, topicB'   | %w[topicA topicB]
      %w[TopicA topicA]          | %w[TopicA]
    end

    with_them do
      it 'normalizes the assigned value' do
        expect(described_class.new(project, value).names).to eq(expected_names)
      end
    end
  end

  describe '#validate_new_topics' do
    before_all do
      create(:topic, name: 'bx::code::c', slug: 'bxcodec', organization: project.organization)
      create(:topic, name: 'other organization', slug: 'otherorganization', organization: create(:organization))
    end

    where(:value, :expected_errors) do
      'bx::code::c++'         | ["'bx::code::c++' is invalid: Slug has already been taken"]
      'topic1, bx::code::c++' | ["'bx::code::c++' is invalid: Slug has already been taken"]
      'new topic, newtopic'   | ["'newtopic' is invalid: Slug has already been taken"]
      'café'                  | ["'café' is invalid: Name must only include ASCII characters"]
      'BX::CODE::C, topic1'   | []
      'bx::code::c, newtopic' | []
      'otherorganization'     | []
      ''                      | []
    end

    with_them do
      it 'adds an error on topics for each topic that cannot be created' do
        described_class.new(project, value).validate_new_topics

        expect(project.errors[:topics]).to eq(expected_errors)
      end
    end
  end

  describe 'the limit on topics added at once' do
    def limit_error(limit:, count:)
      format(
        ns_("Topics|can include up to %{limit} new topic at a time (this change adds %{count})",
          "Topics|can include up to %{limit} new topics at a time (this change adds %{count})", limit),
        limit: limit, count: count)
    end

    where(:added, :expected_errors) do
      50 | []
      51 | [{ limit: 50, count: 51 }]
    end

    with_them do
      it 'counts every topic of a new project', :aggregate_failures do
        new_project = build(:project, topic_list: Array.new(added) { |i| "topic#{i}" })

        expect(new_project.valid?).to be(expected_errors.empty?)
        expect(new_project.errors[:topics]).to eq(expected_errors.map { |error| limit_error(**error) })
      end
    end

    it 'reads as a sentence after the attribute name, singular for a limit of one', :aggregate_failures do
      stub_const("#{described_class}::MAX_NEW_TOPICS", 1)
      new_project = build(:project, topic_list: 'a, b')

      expect(new_project.valid?).to be(false)
      expect(new_project.errors.full_messages_for(:topics))
        .to match_array([new_project.errors.full_message(:topics, limit_error(limit: 1, count: 2))])
    end

    context 'when the project has more topics than the limit' do
      before do
        stub_const("#{described_class}::MAX_NEW_TOPICS", 2)
      end

      before_all do
        project.update!(topic_list: 'a, b, c, d')
      end

      where(:value, :expected_errors) do
        'a, b, c, d'          | []
        'd, c, b, a'          | []
        'a, b'                | []
        'A, B, C, D, e, f'    | []
        'a, b, c, d, e, f, g' | [{ limit: 2, count: 3 }]
        'e, F, g'             | [{ limit: 2, count: 3 }]
      end

      with_them do
        it 'counts only the topics the project does not have', :aggregate_failures do
          project.topic_list = value

          expect(project.valid?).to be(expected_errors.empty?)
          expect(project.errors[:topics]).to eq(expected_errors.map { |error| limit_error(**error) })
        end
      end

      it 'saves a list that keeps them and adds up to the limit', :aggregate_failures do
        expect(project.update(topic_list: 'a, b, c, d, e, f')).to be(true)
        expect(project.reload.topic_list).to eq(%w[a b c d e f])
      end
    end
  end

  context 'when the organization has a topic that Ruby and PostgreSQL lowercase differently' do
    # Ruby downcases U+0130 to "i" and a combining dot, PostgreSQL to "i".
    let_it_be_with_refind(:legacy_topic) do
      build(:topic, name: 'İstanbul', slug: 'istanbul', organization: project.organization).tap do |topic|
        topic.save!(validate: false)
      end
    end

    it 'does not validate it as a new topic' do
      described_class.new(project, 'İstanbul, café').validate_new_topics

      expect(project.errors[:topics]).to eq(["'café' is invalid: Name must only include ASCII characters"])
    end

    it 'assigns it to a project that does not have it', :aggregate_failures do
      expect(project.update(topic_list: 'İstanbul')).to be(true)
      expect(project.reload.topics).to contain_exactly(legacy_topic)
    end

    context 'when the project has it' do
      before_all do
        create(:project_topic, project: project, topic: legacy_topic)
      end

      it 'saves a list that keeps it, changed or not', :aggregate_failures do
        expect(project.update(topic_list: 'İstanbul')).to be(true)
        expect(project.update(topic_list: 'İstanbul, foo')).to be(true)
        expect(project.reload.topics).to contain_exactly(legacy_topic, have_attributes(name: 'foo'))
      end
    end
  end
end
