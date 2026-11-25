# frozen_string_literal: true

module RedirectsForMissingPathOnTree
  include SafeFormatHelper

  def redirect_to_tree_root_for_missing_path(project, ref, path, ref_type: nil)
    redirect_to project_tree_path(project, ref, ref_type: ref_type), notice: missing_path_on_ref(path, ref)
  end

  private

  def missing_path_on_ref(path, ref)
    ref_name = Gitlab::Git.commit_id?(ref) ? Commit.truncate_sha(ref) : ref

    safe_format(
      _("%{path} doesn't exist on %{ref}, so you're viewing the root of %{ref}."),
      path: helpers.content_tag(:code, truncate_path(path)),
      ref: helpers.content_tag(:strong, ref_name, class: 'ref-name')
    )
  end

  def truncate_path(path)
    path.reverse.truncate(60, separator: "/").reverse
  end
end
