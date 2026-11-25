# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::EventProperties, feature_category: :global_search do
  using RSpec::Parameterized::TableSyntax

  subject(:properties) do
    described_class.new(
      params: Search::Params.new({ search: query, scope: scope }.merge(params), detect_abuse: false),
      search_type: search_type,
      scope: scope
    ).to_h
  end

  let(:query) { 'foo' }
  let(:scope) { 'merge_requests' }
  let(:search_type) { 'advanced' }
  let(:params) { {} }

  describe 'filters' do
    it 'is none without filters' do
      expect(properties[:filters]).to eq('none')
    end

    where(:params, :filters) do
      { state: 'closed' }                                       | 'state=closed'
      { state: 'all' }                                          | 'none'
      { state: 'anything' }                                     | 'state'
      { fields: ['title'] }                                     | 'fields=title'
      { confidential: 'false' }                                 | 'confidential=false'
      { include_archived: 'false' }                             | 'none'
      { include_archived: 'true' }                              | 'include_archived=true'
      { exclude_forks: 'false' }                                | 'none'
      { exclude_forks: 'true' }                                 | 'exclude_forks=true'
      { exclude_forks: 'true', source: 'api' }                  | 'none'
      { exclude_forks: 'false', source: 'api' }                 | 'exclude_forks=false'
      { regex: 'false' }                                        | 'none'
      { regex: 'true' }                                         | 'regex=true'
      { label_name: ['bug'] }                                   | 'label_name'
      { author_username: 'alice', not: { source_branch: 'x' } } | 'author_username,not_source_branch'
      { language: ['Ruby'], repository_ref: 'main' }            | 'language'
      { label_name: [''], assignee_ids: [''] }                  | 'none'
      { created_after: '2026-01-01' }                           | 'created_after'
      { state: 'opened', label_name: ['bug'], milestone_title: 'v1' } | 'label_name,milestone_title,state=opened'
    end

    with_them do
      it 'records names, and values only for fixed choices' do
        expect(properties[:filters]).to eq(filters)
      end
    end

    it 'records the type filter by the name callers send' do
      properties = described_class.new(
        params: Search::Params.new({ search: query, type: ['issue'] }, detect_abuse: false),
        search_type: search_type,
        scope: 'work_items'
      ).to_h

      expect(properties[:filters]).to eq('type')
    end

    context 'when an API request omits regex' do
      let(:params) { { source: 'api' } }

      it 'is none, because Zoekt defaults to regular expression mode for the API' do
        expect(properties[:filters]).to eq('none')
      end
    end

    context 'when an API request turns regex off' do
      let(:params) { { source: 'api', regex: false } }

      specify { expect(properties[:filters]).to eq('regex=false') }
    end

    context 'when regex is not a scalar' do
      let(:search_type) { 'zoekt' }
      let(:scope) { 'blobs' }
      let(:query) { 'foo -bar' }

      where(:regex) { [[['1']], [ActionController::Parameters.new(a: '1')]] }

      with_them do
        let(:params) { { regex: regex } }

        it 'treats regex as absent' do
          expect(properties).to eq(filters: 'none', operators: 'none')
        end
      end
    end

    it 'never records the value of a name-only filter' do
      expect(described_class.new(
        params: Search::Params.new({ search: query, author_username: 'secret-user' }, detect_abuse: false),
        search_type: search_type,
        scope: scope
      ).to_h.values.join).not_to include('secret-user')
    end
  end

  describe 'operators' do
    where(:search_type, :scope, :params, :query, :operators) do
      'advanced' | 'merge_requests' | {}                 | 'foo'                         | 'none'
      'advanced' | 'merge_requests' | {}                 | '"gem sidekiq"'               | 'phrase'
      'advanced' | 'merge_requests' | {}                 | 'display -banner'             | 'exclude'
      'advanced' | 'merge_requests' | {}                 | 'display | banner'            | 'or'
      'advanced' | 'merge_requests' | {}                 | 'display +banner'             | 'and'
      'advanced' | 'merge_requests' | {}                 | 'error 50*'                   | 'prefix'
      'advanced' | 'merge_requests' | {}                 | 'J~ Doe'                      | 'fuzzy'
      'advanced' | 'merge_requests' | {}                 | '"gem sidekiq"~2'             | 'phrase'
      'advanced' | 'merge_requests' | {}                 | '"gem sidekiq"~2 Doe~'        | 'fuzzy,phrase'
      'advanced' | 'merge_requests' | {}                 | 'fix !23456'                  | 'reference'
      'advanced' | 'merge_requests' | {}                 | '#23456'                      | 'none'
      'advanced' | 'work_items'     | {}                 | '#23456'                      | 'reference'
      'advanced' | 'work_items'     | {}                 | '#12 foo'                     | 'none'
      'advanced' | 'merge_requests' | {}                 | 'foo-bar --verbose'           | 'none'
      'advanced' | 'merge_requests' | {}                 | 'filename:x.rb'               | 'none'
      'advanced' | 'blobs'          | {}                 | 'foo filename:*spec.rb'       | 'file_filter'
      'advanced' | 'blobs'          | {}                 | 'foo filename:"my file.rb"'   | 'file_filter'
      'advanced' | 'blobs'          | {}                 | '"a b" -path:"c d"'          | 'negated_file_filter,phrase'
      'advanced' | 'blobs'          | {}                 | 'filename:"x.rb" "a b"'      | 'file_filter,phrase'
      'advanced' | 'blobs'          | {}                 | 'foo -path:spec -bar'         | 'exclude,negated_file_filter'
      'advanced' | 'wiki_blobs'     | {}                 | 'foo extension:md'            | 'file_filter'
      'zoekt'    | 'blobs'          | {}                 | 'foo -bar "baz" or qux'       | 'none'
      'zoekt'    | 'blobs'          | {}                 | 'foo file:js -file:test' | 'file_filter,negated_file_filter'
      'zoekt'    | 'blobs'          | {}                 | 'foo f:rb -filename:spec' | 'file_filter,negated_file_filter'
      'zoekt'    | 'blobs'          | {}                 | 'foo repo:bar'                | 'syntax_filter'
      'zoekt'    | 'blobs'          | { regex: true }    | 'foo -bar "baz" or qux'       | 'exclude,or,phrase'
      'zoekt'    | 'blobs'          | { regex: true }    | 'foo file:"a b"'              | 'file_filter'
      'zoekt'    | 'blobs'          | { source: 'api' }  | 'foo -bar lang:ruby'          | 'exclude,syntax_filter'
      'zoekt'    | 'blobs'          | {}                 | 'foo sym:x -case:yes' | 'negated_syntax_filter,syntax_filter'
      'basic'    | 'blobs'          | {}                 | 'foo -extension:md "bar"'     | 'negated_file_filter'
      'basic'    | 'wiki_blobs'     | {}                 | 'foo filename:home.md'        | 'file_filter'
      'basic'    | 'commits'        | {}                 | '"bar baz"'                   | 'none'
      'basic'    | 'issues'         | {}                 | '"bar baz" -qux'              | 'phrase'
      'basic'    | 'issues'         | {}                 | 'foo #12'                     | 'reference'
      'basic'    | 'merge_requests' | {}                 | 'foo !12'                     | 'none'
      'basic'    | 'merge_requests' | {}                 | 'foo #12'                     | 'reference'
      'semantic' | 'blobs'          | {}                 | '"bar baz"'                   | 'none'
    end

    with_them do
      it 'records the operator classes the engine interprets' do
        expect(properties[:operators]).to eq(operators)
      end
    end

    it 'never records the query text' do
      properties = described_class.new(
        params: Search::Params.new({ search: '"secret phrase" filename:secret.rb' }, detect_abuse: false),
        search_type: 'advanced',
        scope: 'blobs'
      ).to_h

      expect(properties.values.join).not_to include('secret')
    end
  end
end
