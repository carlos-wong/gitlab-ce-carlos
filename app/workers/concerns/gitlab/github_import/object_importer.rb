# frozen_string_literal: true

module Gitlab
  module GithubImport
    # ObjectImporter defines the base behaviour for every Sidekiq worker that
    # imports a single resource such as a note or pull request.
    module ObjectImporter
      extend ActiveSupport::Concern

      included do
        include ApplicationWorker

        sidekiq_options retry: 3
        include GithubImport::Queue
        include ReschedulingMethods
        include Gitlab::NotifyUponDeath

        feature_category :importers
        worker_has_external_dependencies!
      end

      # project - An instance of `Project` to import the data into.
      # client - An instance of `Gitlab::GithubImport::Client`
      # hash - A Hash containing the details of the object to import.
      def import(project, client, hash)
        if project.import_state&.canceled?
          info(project.id, message: 'project import canceled')

          return
        end

        object = representation_class.from_json_hash(hash)

        # To better express in the logs what object is being imported.
        self.github_identifiers = object.github_identifiers
        info(project.id, message: 'starting importer')

        importer_class.new(object, project, client).execute

        Gitlab::GithubImport::ObjectCounter.increment(project, object_type, :imported)

        info(project.id, message: 'importer finished')
      rescue NoMethodError => e
        # This exception will be more useful in development when a new
        # Representation is created but the developer forgot to add a
        # `:github_identifiers` field.
        Gitlab::Import::ImportFailureService.track(
          project_id: project.id,
          error_source: importer_class.name,
          exception: e,
          fail_import: true
        )

        raise(e)
      rescue StandardError => e
        Gitlab::Import::ImportFailureService.track(
          project_id: project.id,
          error_source: importer_class.name,
          exception: e
        )
      end

      def object_type
        raise NotImplementedError
      end

      # Returns the representation class to use for the object. This class must
      # define the class method `from_json_hash`.
      def representation_class
        raise NotImplementedError
      end

      # Returns the class to use for importing the object.
      def importer_class
        raise NotImplementedError
      end

      private

      attr_accessor :github_identifiers

      def info(project_id, extra = {})
        Logger.info(log_attributes(project_id, extra))
      end

      def log_attributes(project_id, extra = {})
        extra.merge(
          project_id: project_id,
          importer: importer_class.name,
          github_identifiers: github_identifiers
        )
      end
    end
  end
end
