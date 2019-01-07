# frozen_string_literal: true

class ClusterablePresenter < Gitlab::View::Presenter::Delegated
  presents :clusterable

  def self.fabricate(clusterable, **attributes)
    presenter_class = "#{clusterable.class.name}ClusterablePresenter".constantize
    attributes_with_presenter_class = attributes.merge(presenter_class: presenter_class)

    Gitlab::View::Presenter::Factory
      .new(clusterable, attributes_with_presenter_class)
      .fabricate!
  end

  def can_add_cluster?
    can?(current_user, :add_cluster, clusterable)
  end

  def can_create_cluster?
    can?(current_user, :create_cluster, clusterable)
  end

  def index_path
    polymorphic_path([clusterable, :clusters])
  end

  def new_path
    new_polymorphic_path([clusterable, :cluster])
  end

  def create_user_clusters_path
    polymorphic_path([clusterable, :clusters], action: :create_user)
  end

  def create_gcp_clusters_path
    polymorphic_path([clusterable, :clusters], action: :create_gcp)
  end

  def cluster_status_cluster_path(cluster, params = {})
    raise NotImplementedError
  end

  def install_applications_cluster_path(cluster, application)
    raise NotImplementedError
  end

  def cluster_path(cluster, params = {})
    raise NotImplementedError
  end

  def empty_state_help_text
    nil
  end

  def sidebar_text
    raise NotImplementedError
  end

  def learn_more_link
    raise NotImplementedError
  end
end
