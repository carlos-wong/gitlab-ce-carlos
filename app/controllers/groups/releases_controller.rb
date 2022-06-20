# frozen_string_literal: true

module Groups
  class ReleasesController < Groups::ApplicationController
    feature_category :release_evidence

    def index
      respond_to do |format|
        format.json do
          render json: ReleaseSerializer.new.represent(releases)
        end
      end
    end

    private

    def releases
      if Feature.enabled?(:group_releases_finder_inoperator)
        Releases::GroupReleasesFinder
          .new(@group, current_user)
          .execute(preload: false)
          .page(params[:page])
          .per(30)
      else
        ReleasesFinder
          .new(@group, current_user, { include_subgroups: true })
          .execute(preload: false)
          .page(params[:page])
          .per(30)
      end
    end
  end
end
