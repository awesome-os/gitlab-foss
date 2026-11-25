# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query', feature_category: :groups_and_projects do
  include GraphqlHelpers

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }

  let_it_be(:group_namespace) { create(:group, :private) }
  let_it_be(:public_group_namespace) { create(:group, :public) }
  let_it_be(:user_namespace) { create(:user_namespace, owner: user) }
  let_it_be(:project) { create(:project, group: group_namespace) }

  describe '.namespace' do
    subject { post_graphql(query, current_user: current_user) }

    let(:current_user) { user }

    let(:query) { graphql_query_for(:namespace, { 'fullPath' => target_namespace.full_path }, all_graphql_fields_for('Namespace')) }
    let(:query_result) { graphql_data['namespace'] }

    shared_examples 'retrieving a namespace' do
      context 'authorised query' do
        before do
          subject
        end

        it_behaves_like 'a working graphql query'

        it 'fetches the expected data' do
          expect(query_result).to include(
            'fullPath' => target_namespace.full_path,
            'name' => target_namespace.name,
            'crossProjectPipelineAvailable' => target_namespace.licensed_feature_available?(:cross_project_pipeline),
            'achievementsPath' => achievements_path
          )
        end
      end

      context 'unauthorised query' do
        before do
          subject
        end

        context 'anonymous user' do
          let(:current_user) { nil }

          it 'does not retrieve the record' do
            expect(query_result).to be_nil
          end
        end

        context 'the current user does not have permission' do
          let(:current_user) { other_user }

          it 'does not retrieve the record' do
            expect(query_result).to be_nil
          end
        end
      end
    end

    context 'when used with a public group' do
      let(:target_namespace) { public_group_namespace }
      let(:achievements_path) { ::Gitlab::Routing.url_helpers.group_achievements_path(target_namespace) }

      before do
        subject
      end

      it_behaves_like 'a working graphql query'

      context 'when user is a member' do
        before do
          public_group_namespace.add_developer(user)
        end

        it 'fetches the expected data' do
          expect(query_result).to include(
            'fullPath' => target_namespace.full_path,
            'name' => target_namespace.name,
            'achievementsPath' => achievements_path
          )
        end
      end

      context 'when user is anonymous' do
        let(:current_user) { nil }

        it 'fetches the expected data' do
          expect(query_result).to include(
            'fullPath' => target_namespace.full_path,
            'name' => target_namespace.name,
            'achievementsPath' => achievements_path
          )
        end
      end

      context 'when user is not a member' do
        let(:current_user) { other_user }

        it 'fetches the expected data' do
          expect(query_result).to include(
            'fullPath' => target_namespace.full_path,
            'name' => target_namespace.name,
            'achievementsPath' => achievements_path
          )
        end
      end
    end

    context 'when used with a private namespace' do
      context 'retrieving a group' do
        it_behaves_like 'retrieving a namespace' do
          let(:target_namespace) { group_namespace }
          let(:achievements_path) { ::Gitlab::Routing.url_helpers.group_achievements_path(target_namespace) }

          before do
            group_namespace.add_developer(user)
          end
        end
      end

      context 'retrieving a user namespace' do
        it_behaves_like 'retrieving a namespace' do
          let(:target_namespace) { user_namespace }
          let(:achievements_path) { nil }
        end
      end

      context 'retrieving a project' do
        it_behaves_like 'retrieving a namespace' do
          let(:target_namespace) { project }
          let(:achievements_path) { nil }

          before do
            group_namespace.add_developer(user)
          end
        end
      end
    end

    context 'when authenticating with a granular token' do
      let(:query) { graphql_query_for(:namespace, { 'fullPath' => target_namespace.full_path }, 'id') }
      let(:request) { post_graphql(query, token: { personal_access_token: pat }) }

      context 'with a project namespace' do
        it_behaves_like 'authorizing granular token permissions for GraphQL', :read_namespace do
          let(:target_namespace) { project }
          let(:boundary_object) { project }

          before do
            group_namespace.add_developer(user)
          end
        end
      end

      context 'with a group namespace' do
        it_behaves_like 'authorizing granular token permissions for GraphQL', :read_namespace do
          let(:target_namespace) { group_namespace }
          let(:boundary_object) { group_namespace }

          before do
            group_namespace.add_developer(user)
          end
        end
      end

      context 'with a user namespace' do
        it_behaves_like 'authorizing granular token permissions for GraphQL', :read_namespace do
          let(:target_namespace) { user_namespace }
          let(:boundary_object) { :user }
        end
      end

      context 'when querying the user permissions' do
        it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
          :read_namespace do
          let(:target_namespace) { group_namespace }
          let(:boundary_object) { group_namespace }
          let(:query) do
            graphql_query_for(:namespace, { 'fullPath' => target_namespace.full_path }, 'userPermissions { readNamespace }')
          end

          let(:skipped_data_path) { %i[namespace user_permissions] }

          before do
            group_namespace.add_developer(user)
          end
        end
      end

      context 'when querying the markdown paths' do
        using RSpec::Parameterized::TableSyntax

        before_all do
          group_namespace.add_developer(user)
        end

        # Every field of UserNamespaceMarkdownPaths falls back to null, so its row reads __typename.
        where(:target_namespace, :boundary_object, :namespace_fields, :skipped_data_path) do
          ref(:group_namespace) | ref(:group_namespace) | 'markdownPaths { uploadsPath }' | %i[namespace markdown_paths uploads_path]
          ref(:project)         | ref(:project)         | 'markdownPaths { uploadsPath }' | %i[namespace markdown_paths uploads_path]
          ref(:user_namespace)  | :user                 | 'markdownPaths { __typename }'  | %i[namespace markdown_paths __typename]
        end

        with_them do
          it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
            :read_namespace do
            let(:query) do
              graphql_query_for(:namespace, { 'fullPath' => target_namespace.full_path }, namespace_fields)
            end
          end
        end
      end

      context 'when querying the link paths, metadata and sidebar' do
        using RSpec::Parameterized::TableSyntax

        let(:query) do
          graphql_query_for(:namespace, { 'fullPath' => target_namespace.full_path }, namespace_fields)
        end

        before_all do
          group_namespace.add_developer(user)
        end

        # The sidebar counts are null for a user namespace.
        where(:target_namespace, :boundary_object, :namespace_fields, :skipped_data_path) do
          ref(:group_namespace) | ref(:group_namespace) | 'linkPaths { issuesList }'                  | %i[namespace link_paths issues_list]
          ref(:project)         | ref(:project)         | 'linkPaths { issuesList }'                  | %i[namespace link_paths issues_list]
          ref(:user_namespace)  | :user                 | 'linkPaths { register }'                    | %i[namespace link_paths register]
          ref(:group_namespace) | ref(:group_namespace) | 'linkPaths { newCommentTemplate { href } }' | %i[namespace link_paths new_comment_template]
          ref(:project)         | ref(:project)         | 'linkPaths { newCommentTemplate { href } }' | %i[namespace link_paths new_comment_template]
          ref(:group_namespace) | ref(:group_namespace) | 'metadata { groupId }'                      | %i[namespace metadata group_id]
          ref(:project)         | ref(:project)         | 'metadata { groupId }'                      | %i[namespace metadata group_id]
          ref(:user_namespace)  | :user                 | 'metadata { maxAttachmentSize }'            | %i[namespace metadata max_attachment_size]
          ref(:group_namespace) | ref(:group_namespace) | 'sidebar { openIssuesCount }'               | %i[namespace sidebar open_issues_count]
          ref(:project)         | ref(:project)         | 'sidebar { openIssuesCount }'               | %i[namespace sidebar open_issues_count]
        end

        with_them do
          it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
            :read_namespace
        end
      end

      # The settings need the owner role, so a token of an owner that only reads the namespace
      # does not read them.
      context 'when querying the namespace settings' do
        let_it_be(:owned_group) { create(:group, :private, owners: user) }

        let(:boundary_object) { owned_group }
        let(:query) do
          graphql_query_for(:namespace, { 'fullPath' => owned_group.full_path }, 'namespaceSettings { __typename }')
        end

        it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
          [:read_namespace, :read_namespace_setting] do
          let(:skipped_data_path) { %i[namespace namespace_settings __typename] }
        end

        it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_namespace do
          let(:parent_data_path) { %i[namespace] }
          let(:field_data_path) { %i[namespace namespace_settings] }
        end
      end

      context 'when querying a field that needs its own permission' do
        using RSpec::Parameterized::TableSyntax

        let(:query) do
          graphql_query_for(:namespace, { 'fullPath' => target_namespace.full_path }, namespace_fields)
        end

        before_all do
          group_namespace.add_developer(user)
          user.user_preference.update!(issues_sort: 'created_desc')
        end

        shared_examples 'a field that needs its own permission' do |permission|
          it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
            [:read_namespace, permission] do
            let(:skipped_data_path) { field_data_path }
          end

          it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_namespace do
            let(:parent_data_path) { field_data_path.first(2) }
          end
        end

        context 'when querying the default branch of a project' do
          let(:target_namespace) { project }
          let(:boundary_object) { project }
          let(:namespace_fields) { 'metadata { ... on ProjectNamespaceMetadata { defaultBranch } }' }
          let(:field_data_path) { %i[namespace metadata default_branch] }

          it_behaves_like 'a field that needs its own permission', :read_code
        end

        context 'when querying the contribution guide of a project' do
          let_it_be(:guide_project) do
            create(:project, :custom_repo, group: group_namespace, files: { 'CONTRIBUTING.md' => 'Contribute' })
          end

          let(:target_namespace) { guide_project }
          let(:boundary_object) { guide_project }
          let(:namespace_fields) { 'linkPaths { contributionGuidePath }' }
          let(:field_data_path) { %i[namespace link_paths contribution_guide_path] }

          it_behaves_like 'a field that needs its own permission', :read_code
        end

        context 'when querying the initial sort of a user namespace' do
          let(:target_namespace) { user_namespace }
          let(:boundary_object) { :user }
          let(:namespace_fields) { 'metadata { initialSort }' }
          let(:field_data_path) { %i[namespace metadata initial_sort] }

          it_behaves_like 'a field that needs its own permission', :read_user_preference
        end

        context 'when querying whether a group has projects' do
          let(:target_namespace) { group_namespace }
          let(:boundary_object) { group_namespace }
          let(:namespace_fields) { 'metadata { ... on GroupNamespaceMetadata { hasProjects } }' }
          let(:field_data_path) { %i[namespace metadata has_projects] }

          it_behaves_like 'a field that needs its own permission', :read_project
        end

        context 'when querying the work item feed paths' do
          where(:target_namespace, :boundary_object, :namespace_fields, :field_data_path) do
            ref(:group_namespace) | ref(:group_namespace) | 'linkPaths { rssPath }'      | %i[namespace link_paths rss_path]
            ref(:project)         | ref(:project)         | 'linkPaths { rssPath }'      | %i[namespace link_paths rss_path]
            ref(:group_namespace) | ref(:group_namespace) | 'linkPaths { calendarPath }' | %i[namespace link_paths calendar_path]
            ref(:project)         | ref(:project)         | 'linkPaths { calendarPath }' | %i[namespace link_paths calendar_path]
          end

          with_them do
            it_behaves_like 'a field that needs its own permission', :read_work_item
          end
        end

        # On a public namespace the public access rule admits a token without read_work_item to the
        # feed paths and resolves them as anonymous, also after a sibling field resolved as the user.
        context 'when querying the work item feed paths of a public namespace after another link path' do
          let_it_be(:public_project) { create(:project, :public, group: public_group_namespace) }

          let(:namespace_fields) { 'linkPaths { issuesList rssPath calendarPath }' }
          let(:feed_token) { /feed_token=#{::User.prefix_for_feed_token}\h+-#{user.id}\b/ }

          let(:pat) do
            create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(boundary_object), permissions: permissions)
          end

          before_all do
            public_group_namespace.add_developer(user)
          end

          where(:target_namespace, :boundary_object) do
            ref(:public_group_namespace) | ref(:public_group_namespace)
            ref(:public_project)         | ref(:public_project)
          end

          with_them do
            context 'when the token cannot read the work items' do
              let(:permissions) { %w[read_namespace] }

              it 'returns the feed paths without a feed token', :aggregate_failures do
                request

                expect(graphql_errors).to be_nil
                expect(graphql_data_at(:namespace, :link_paths, :issues_list)).to be_present
                expect(graphql_data_at(:namespace, :link_paths, :rss_path)).to be_present
                expect(graphql_data_at(:namespace, :link_paths, :rss_path)).not_to include('feed_token')
                expect(graphql_data_at(:namespace, :link_paths, :calendar_path)).to be_present
                expect(graphql_data_at(:namespace, :link_paths, :calendar_path)).not_to include('feed_token')
              end
            end

            context 'when the token can read the work items' do
              let(:permissions) { %w[read_namespace read_work_item] }

              it 'returns the feed paths with the feed token of its user', :aggregate_failures do
                request

                expect(graphql_errors).to be_nil
                expect(graphql_data_at(:namespace, :link_paths, :rss_path)).to match(feed_token)
                expect(graphql_data_at(:namespace, :link_paths, :calendar_path)).to match(feed_token)
              end
            end
          end
        end

        context 'when querying the email address for new work items' do
          let(:target_namespace) { project }
          let(:boundary_object) { project }
          let(:namespace_fields) { 'linkPaths { ... on ProjectNamespaceLinks { newWorkItemEmailAddress } }' }
          let(:field_data_path) { %i[namespace link_paths new_work_item_email_address] }

          before do
            stub_incoming_email_setting(enabled: true, address: 'incoming+%{key}@localhost.com')
          end

          it_behaves_like 'a field that needs its own permission', :create_work_item
        end

        context 'when querying the initial sort of a project namespace' do
          let(:target_namespace) { project }
          let(:boundary_object) { project }
          let(:namespace_fields) { 'metadata { initialSort }' }

          it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_namespace do
            let(:parent_data_path) { %i[namespace metadata] }
            let(:field_data_path) { %i[namespace metadata initial_sort] }
          end
        end

        context 'when querying the export email' do
          let(:target_namespace) { group_namespace }
          let(:boundary_object) { group_namespace }
          let(:namespace_fields) { 'linkPaths { userExportEmail }' }

          it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_namespace do
            let(:parent_data_path) { %i[namespace link_paths] }
            let(:field_data_path) { %i[namespace link_paths user_export_email] }
          end

          context 'when the token can also read the emails of its user' do
            let(:pat) do
              create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(group_namespace),
                permissions: %w[read_namespace],
                additional_scopes: [{ boundary: ::Authz::Boundary.for(:user), permissions: %w[read_email] }])
            end

            it 'returns the email' do
              request

              expect(graphql_errors).to be_nil
              expect(graphql_data_at(:namespace, :link_paths, :user_export_email))
                .to eq(user.notification_email_or_default)
            end
          end
        end
      end
    end

    describe 'linkPaths' do
      let_it_be(:test_project) { create(:project, :public) }
      let_it_be(:target_namespace) { test_project.project_namespace }

      let(:current_user) { user }

      describe 'newWorkItemEmailAddress' do
        let(:query_fields) do
          <<~QUERY
          linkPaths {
            ... on ProjectNamespaceLinks {
              newWorkItemEmailAddress
            }
          }
          QUERY
        end

        let(:query_string) { graphql_query_for(:namespace, { 'fullPath' => test_project.full_path }, query_fields) }

        context 'when work item creation via email is supported' do
          before do
            stub_incoming_email_setting(enabled: true, address: 'incoming+%{key}@localhost.com')
          end

          context 'when user has incoming email token' do
            before do
              user.ensure_incoming_email_token!
            end

            it 'returns the work item email address' do
              post_graphql(query_string, current_user: current_user)

              expected_address = "incoming+#{test_project.full_path_slug}-#{test_project.id}-" \
                "#{user.incoming_email_token}-issue@localhost.com"

              expect(graphql_dig_at(graphql_data, :namespace, :link_paths,
                :new_work_item_email_address)).to eq(expected_address)
            end

            context 'when using a read_api scoped token' do
              let(:token) { create(:personal_access_token, user: user, scopes: [:read_api]) }

              it 'does not return the work item email address' do
                post_graphql(query_string, current_user: current_user, token: { personal_access_token: token })

                expect(graphql_dig_at(graphql_data, :namespace, :link_paths,
                  :new_work_item_email_address)).to be_nil
              end
            end

            context 'when using an api scoped token' do
              let(:token) { create(:personal_access_token, user: user, scopes: [:api]) }

              it 'returns the work item email address' do
                post_graphql(query_string, current_user: current_user, token: { personal_access_token: token })

                expected_address = "incoming+#{test_project.full_path_slug}-#{test_project.id}-" \
                  "#{user.incoming_email_token}-issue@localhost.com"

                expect(graphql_dig_at(graphql_data, :namespace, :link_paths,
                  :new_work_item_email_address)).to eq(expected_address)
              end
            end
          end

          context 'when user does not have incoming email token' do
            before do
              user.update!(incoming_email_token: nil)
            end

            it 'generates and returns the work item email address' do
              post_graphql(query_string, current_user: current_user)

              expect(graphql_dig_at(graphql_data, :namespace, :link_paths,
                :new_work_item_email_address)).to be_present
              expect(user.reload.incoming_email_token).to be_present

              expected_address = "incoming+#{test_project.full_path_slug}-#{test_project.id}-" \
                "#{user.incoming_email_token}-issue@localhost.com"

              expect(graphql_dig_at(graphql_data, :namespace, :link_paths,
                :new_work_item_email_address)).to eq(expected_address)
            end
          end
        end

        context 'when work item creation via email is not supported' do
          before do
            stub_incoming_email_setting(enabled: false)
          end

          it 'returns nil' do
            post_graphql(query_string, current_user: current_user)

            expect(graphql_dig_at(graphql_data, :namespace, :link_paths, :new_work_item_email_address)).to be_nil
          end
        end

        context 'when user is nil' do
          let(:current_user) { nil }

          it 'returns nil' do
            post_graphql(query_string, current_user: current_user)

            expect(graphql_dig_at(graphql_data, :namespace, :link_paths, :new_work_item_email_address)).to be_nil
          end
        end
      end

      describe 'releasesPath, projectImportJiraPath, rssPath, calendarPath' do
        let(:query_fields) do
          <<~QUERY
          linkPaths {
            ... on ProjectNamespaceLinks {
              releasesPath
              projectImportJiraPath
              rssPath
              calendarPath
            }
          }
          QUERY
        end

        let(:query_string) { graphql_query_for(:namespace, { 'fullPath' => test_project.full_path }, query_fields) }

        it 'returns the project link paths' do
          post_graphql(query_string, current_user: current_user)

          link_paths = graphql_dig_at(graphql_data, :namespace, :link_paths)

          expect(link_paths['releasesPath']).to eq(
            ::Gitlab::Routing.url_helpers.project_releases_path(test_project, format: :json)
          )
          expect(link_paths['projectImportJiraPath']).to eq(
            ::Gitlab::Routing.url_helpers.project_import_jira_path(test_project)
          )
          expect(link_paths['rssPath']).to match(
            %r{^/#{Regexp.escape(test_project.full_path)}/-/work_items\.atom\?feed_token=glft-.+-#{user.id}$}
          )
          expect(link_paths['calendarPath']).to match(
            %r{^/#{Regexp.escape(test_project.full_path)}/-/work_items\.ics\?feed_token=glft-.+-#{user.id}$}
          )
        end

        context 'when user is anonymous' do
          let(:current_user) { nil }

          it 'returns paths without feed tokens' do
            post_graphql(query_string, current_user: current_user)

            link_paths = graphql_dig_at(graphql_data, :namespace, :link_paths)

            expect(link_paths['rssPath']).to eq(
              ::Gitlab::Routing.url_helpers.project_work_items_path(test_project, format: :atom)
            )
            expect(link_paths['calendarPath']).to eq(
              ::Gitlab::Routing.url_helpers.project_work_items_path(test_project, format: :ics)
            )
          end
        end
      end

      describe 'group namespace link paths' do
        let_it_be(:test_group) { create(:group, :public) }
        let_it_be(:target_namespace) { test_group }

        let(:query_fields) do
          <<~QUERY
          linkPaths {
            ... on GroupNamespaceLinks {
              rssPath
              calendarPath
            }
          }
          QUERY
        end

        let(:query_string) { graphql_query_for(:namespace, { 'fullPath' => test_group.full_path }, query_fields) }

        it 'returns the group link paths with feed tokens' do
          post_graphql(query_string, current_user: current_user)

          link_paths = graphql_dig_at(graphql_data, :namespace, :link_paths)

          expect(link_paths['rssPath']).to match(
            %r{^/groups/#{Regexp.escape(test_group.full_path)}/-/work_items\.atom\?feed_token=glft-.+-#{user.id}$}
          )
          expect(link_paths['calendarPath']).to match(
            %r{^/groups/#{Regexp.escape(test_group.full_path)}/-/work_items\.ics\?feed_token=glft-.+-#{user.id}$}
          )
        end

        context 'when user is anonymous' do
          let(:current_user) { nil }

          it 'returns paths without feed tokens' do
            post_graphql(query_string, current_user: current_user)

            link_paths = graphql_dig_at(graphql_data, :namespace, :link_paths)

            expect(link_paths['rssPath']).to eq(
              ::Gitlab::Routing.url_helpers.group_work_items_path(test_group, format: :atom)
            )
            expect(link_paths['calendarPath']).to eq(
              ::Gitlab::Routing.url_helpers.group_work_items_path(test_group, format: :ics)
            )
          end
        end
      end
    end
  end
end
