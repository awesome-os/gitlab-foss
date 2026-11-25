# frozen_string_literal: true

module UserSettings
  class GpgKeysController < ApplicationController
    before_action :set_gpg_key, only: [:destroy, :revoke]

    feature_category :repository_services

    def index
      @gpg_keys = current_user.gpg_keys.with_subkeys
      @gpg_key = GpgKey.new
    end

    def create
      @gpg_key = GpgKeys::CreateService.new(current_user, gpg_key_params).execute

      return redirect_to user_settings_gpg_keys_path if @gpg_key.persisted?

      stored_key = @gpg_key.stored_duplicate
      return update_stored_key(stored_key) if stored_key

      render_index_with_form
    end

    def destroy
      GpgKeys::DestroyService.new(current_user).execute(@gpg_key)

      respond_to do |format|
        format.html { redirect_to user_settings_gpg_keys_url, status: :found }
        format.js { head :ok }
      end
    end

    def revoke
      @gpg_key.revoke

      respond_to do |format|
        format.html { redirect_to user_settings_gpg_keys_url, status: :found }
        format.js { head :ok }
      end
    end

    private

    def gpg_key_params
      params.require(:gpg_key).permit(:key)
    end

    def update_stored_key(stored_key)
      result = ::Repositories::GpgKeys::UpdateService
        .new(stored_key, current_user: current_user, params: gpg_key_params)
        .execute

      if result.success?
        notice = if result.payload[:updated]
                   s_('Profiles|GPG key updated.')
                 else
                   s_('Profiles|This GPG key is already up to date.')
                 end

        redirect_to user_settings_gpg_keys_path, notice: notice
      else
        @gpg_key = GpgKey.new(key: gpg_key_params[:key])
        @gpg_key.errors.add(:base, result.message,
          help_page_url: help_page_url('user/project/repository/signed_commits/gpg.md', anchor: 'update-a-gpg-key'))
        render_index_with_form
      end
    end

    def render_index_with_form
      @gpg_keys = current_user.gpg_keys.with_subkeys
      render :index
    end

    def set_gpg_key
      @gpg_key = current_user.gpg_keys.find(params.permit(:id)[:id])
    end
  end
end
