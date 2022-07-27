# frozen_string_literal: true

databases = ActiveRecord::Tasks::DatabaseTasks.setup_initial_database_yaml

def each_database(databases, include_geo: false)
  ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |database|
    next if !include_geo && database == 'geo'

    yield database
  end
end

namespace :gitlab do
  namespace :db do
    desc 'GitLab | DB | Manually insert schema migration version on all configured databases'
    task :mark_migration_complete, [:version] => :environment do |_, args|
      mark_migration_complete(args[:version])
    end

    namespace :mark_migration_complete do
      each_database(databases) do |database_name|
        desc "Gitlab | DB | Manually insert schema migration version on #{database_name} database"
        task database_name, [:version] => :environment do |_, args|
          mark_migration_complete(args[:version], only_on: database_name)
        end
      end
    end

    def mark_migration_complete(version, only_on: nil)
      if version.to_i == 0
        puts 'Must give a version argument that is a non-zero integer'.color(:red)
        exit 1
      end

      Gitlab::Database::EachDatabase.each_database_connection(only: only_on) do |connection, name|
        connection.execute("INSERT INTO schema_migrations (version) VALUES (#{connection.quote(version)})")

        puts "Successfully marked '#{version}' as complete on database #{name}".color(:green)
      rescue ActiveRecord::RecordNotUnique
        puts "Migration version '#{version}' is already marked complete on database #{name}".color(:yellow)
      end
    end

    desc 'GitLab | DB | Drop all tables on all configured databases'
    task drop_tables: :environment do
      drop_tables
    end

    namespace :drop_tables do
      each_database(databases) do |database_name|
        desc "GitLab | DB | Drop all tables on the #{database_name} database"
        task database_name => :environment do
          drop_tables(only_on: database_name)
        end
      end
    end

    def drop_tables(only_on: nil)
      Gitlab::Database::EachDatabase.each_database_connection(only: only_on) do |connection, name|
        # In PostgreSQLAdapter, data_sources returns both views and tables, so use tables instead
        tables = connection.tables

        # Removes the entry from the array
        tables.delete 'schema_migrations'
        # Truncate schema_migrations to ensure migrations re-run
        connection.execute('TRUNCATE schema_migrations') if connection.table_exists? 'schema_migrations'

        # Drop any views
        connection.views.each do |view|
          connection.execute("DROP VIEW IF EXISTS #{connection.quote_table_name(view)} CASCADE")
        end

        # Drop tables with cascade to avoid dependent table errors
        # PG: http://www.postgresql.org/docs/current/static/ddl-depend.html
        # Add `IF EXISTS` because cascade could have already deleted a table.
        tables.each { |t| connection.execute("DROP TABLE IF EXISTS #{connection.quote_table_name(t)} CASCADE") }

        # Drop all extra schema objects GitLab owns
        Gitlab::Database::EXTRA_SCHEMAS.each do |schema|
          connection.execute("DROP SCHEMA IF EXISTS #{connection.quote_table_name(schema)} CASCADE")
        end
      end
    end

    desc 'GitLab | DB | Configures the database by running migrate, or by loading the schema and seeding if needed'
    task configure: :environment do
      databases_with_tasks = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env)

      databases_loaded = []

      if databases_with_tasks.size == 1
        next unless databases_with_tasks.first.name == 'main'

        connection = Gitlab::Database.database_base_models['main'].connection
        databases_loaded << configure_database(connection)
      else
        Gitlab::Database.database_base_models_with_gitlab_shared.each do |name, model|
          next unless databases_with_tasks.any? { |db_with_tasks| db_with_tasks.name == name }

          databases_loaded << configure_database(model.connection, database_name: name)
        end
      end

      Rake::Task['db:seed_fu'].invoke if databases_loaded.present? && databases_loaded.all?
    end

    def configure_database(connection, database_name: nil)
      database_name = ":#{database_name}" if database_name
      load_database = connection.tables.count <= 1

      if load_database
        Gitlab::Database.add_post_migrate_path_to_rails(force: true)
        Rake::Task["db:schema:load#{database_name}"].invoke
      else
        Rake::Task["db:migrate#{database_name}"].invoke
      end

      load_database
    end

    desc 'GitLab | DB | Run database migrations and print `unattended_migrations_completed` if action taken'
    task unattended: :environment do
      no_database = !ActiveRecord::Base.connection.schema_migration.table_exists?
      needs_migrations = ActiveRecord::Base.connection.migration_context.needs_migration?

      if no_database || needs_migrations
        Rake::Task['gitlab:db:configure'].invoke
        puts "unattended_migrations_completed"
      else
        puts "unattended_migrations_static"
      end
    end

    desc 'This adjusts and cleans db/structure.sql - it runs after db:structure:dump'
    task :clean_structure_sql do |task_name|
      ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env).each do |db_config|
        structure_file = ActiveRecord::Tasks::DatabaseTasks.dump_filename(db_config.name)

        schema = File.read(structure_file)

        File.open(structure_file, 'wb+') do |io|
          Gitlab::Database::SchemaCleaner.new(schema).clean(io)
        end
      end

      # Allow this task to be called multiple times, as happens when running db:migrate:redo
      Rake::Task[task_name].reenable
    end

    # Inform Rake that custom tasks should be run every time rake db:structure:dump is run
    #
    # Rails 6.1 deprecates db:structure:dump in favor of db:schema:dump
    Rake::Task['db:structure:dump'].enhance do
      Rake::Task['gitlab:db:clean_structure_sql'].invoke
    end

    # Inform Rake that custom tasks should be run every time rake db:schema:dump is run
    Rake::Task['db:schema:dump'].enhance do
      Rake::Task['gitlab:db:clean_structure_sql'].invoke
    end

    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      # Inform Rake that custom tasks should be run every time rake db:structure:dump is run
      #
      # Rails 6.1 deprecates db:structure:dump in favor of db:schema:dump
      Rake::Task["db:structure:dump:#{name}"].enhance do
        Rake::Task['gitlab:db:clean_structure_sql'].invoke
      end

      Rake::Task["db:schema:dump:#{name}"].enhance do
        Rake::Task['gitlab:db:clean_structure_sql'].invoke
      end
    end

    desc 'Create missing dynamic database partitions'
    task create_dynamic_partitions: :environment do
      Gitlab::Database::Partitioning.sync_partitions
    end

    namespace :create_dynamic_partitions do
      each_database(databases) do |database_name|
        desc "Create missing dynamic database partitions on the #{database_name} database"
        task database_name => :environment do
          Gitlab::Database::Partitioning.sync_partitions(only_on: database_name)
        end
      end
    end

    # This is targeted towards deploys and upgrades of GitLab.
    # Since we're running migrations already at this time,
    # we also check and create partitions as needed here.
    Rake::Task['db:migrate'].enhance do
      Rake::Task['gitlab:db:create_dynamic_partitions'].invoke
    end

    # We'll temporarily skip this enhancement for geo, since in some situations we
    # wish to setup the geo database before the other databases have been setup,
    # and partition management attempts to connect to the main database.
    each_database(databases) do |database_name|
      Rake::Task["db:migrate:#{database_name}"].enhance do
        Rake::Task["gitlab:db:create_dynamic_partitions:#{database_name}"].invoke
      end
    end

    # When we load the database schema from db/structure.sql
    # we don't have any dynamic partitions created. We don't really need to
    # because application initializers/sidekiq take care of that, too.
    # However, the presence of partitions for a table has influence on their
    # position in db/structure.sql (which is topologically sorted).
    #
    # Other than that it's helpful to create partitions early when bootstrapping
    # a new installation.
    Rake::Task['db:schema:load'].enhance do
      Rake::Task['gitlab:db:create_dynamic_partitions'].invoke
    end

    # We'll temporarily skip this enhancement for geo, since in some situations we
    # wish to setup the geo database before the other databases have been setup,
    # and partition management attempts to connect to the main database.
    each_database(databases) do |database_name|
      # :nocov:
      Rake::Task["db:schema:load:#{database_name}"].enhance do
        Rake::Task["gitlab:db:create_dynamic_partitions:#{database_name}"].invoke
      end
      # :nocov:
    end

    # During testing, db:test:load restores the database schema from scratch
    # which does not include dynamic partitions. We cannot rely on application
    # initializers here as the application can continue to run while
    # a rake task reloads the database schema.
    Rake::Task['db:test:load'].enhance do
      # Due to bug in `db:test:load` if many DBs are used
      # the `ActiveRecord::Base.connection` might be switched to another one
      # This is due to `if should_reconnect`:
      # https://github.com/rails/rails/blob/a81aeb63a007ede2fe606c50539417dada9030c7/activerecord/lib/active_record/railties/databases.rake#L622
      ActiveRecord::Base.establish_connection :main # rubocop: disable Database/EstablishConnection

      Rake::Task['gitlab:db:create_dynamic_partitions'].invoke
    end

    desc "Reindex database without downtime to eliminate bloat"
    task reindex: :environment do
      unless Gitlab::Database::Reindexing.enabled?
        puts "This feature (database_reindexing) is currently disabled.".color(:yellow)
        exit
      end

      Gitlab::Database::Reindexing.invoke
    end

    namespace :reindex do
      each_database(databases) do |database_name|
        desc "Reindex #{database_name} database without downtime to eliminate bloat"
        task database_name => :environment do
          unless Gitlab::Database::Reindexing.enabled?
            puts "This feature (database_reindexing) is currently disabled.".color(:yellow)
            exit
          end

          Gitlab::Database::Reindexing.invoke(database_name)
        end
      end
    end

    desc 'Enqueue an index for reindexing'
    task :enqueue_reindexing_action, [:index_name, :database] => :environment do |_, args|
      model = Gitlab::Database.database_base_models[args.fetch(:database, Gitlab::Database::PRIMARY_DATABASE_NAME)]

      Gitlab::Database::SharedModel.using_connection(model.connection) do
        queued_action = Gitlab::Database::PostgresIndex.find(args[:index_name]).queued_reindexing_actions.create!

        puts "Queued reindexing action: #{queued_action}"
        puts "There are #{Gitlab::Database::Reindexing::QueuedAction.queued.size} queued actions in total."
      end

      unless Feature.enabled?(:database_reindexing, type: :ops)
        puts <<~NOTE.color(:yellow)
          Note: database_reindexing feature is currently disabled.

          Enable with: Feature.enable(:database_reindexing)
        NOTE
      end
    end

    desc 'Check if there have been user additions to the database'
    task active: :environment do
      if ActiveRecord::Base.connection.migration_context.needs_migration?
        puts "Migrations pending. Database not active"
        exit 1
      end

      # A list of projects that GitLab creates automatically on install/upgrade
      # gc = Gitlab::CurrentSettings.current_application_settings
      seed_projects = [Gitlab::CurrentSettings.current_application_settings.self_monitoring_project]

      if (Project.count - seed_projects.count {|x| !x.nil? }).eql?(0)
        puts "No user created projects. Database not active"
        exit 1
      end

      puts "Found user created projects. Database active"
      exit 0
    end

    namespace :migration_testing do
      desc 'Run migrations with instrumentation'
      task up: :environment do
        Gitlab::Database::Migrations::Runner.up.run
      end

      desc 'Run down migrations in current branch with instrumentation'
      task down: :environment do
        Gitlab::Database::Migrations::Runner.down.run
      end

      desc 'Sample traditional background migrations with instrumentation'
      task :sample_background_migrations, [:duration_s] => [:environment] do |_t, args|
        duration = args[:duration_s]&.to_i&.seconds || 30.minutes # Default of 30 minutes

        Gitlab::Database::Migrations::Runner.background_migrations.run_jobs(for_duration: duration)
      end

      desc 'Sample batched background migrations with instrumentation'
      task :sample_batched_background_migrations, [:database, :duration_s] => [:environment] do |_t, args|
        database_name = args[:database] || 'main'
        duration = args[:duration_s]&.to_i&.seconds || 30.minutes # Default of 30 minutes

        Gitlab::Database::Migrations::Runner.batched_background_migrations(for_database: database_name)
                                            .run_jobs(for_duration: duration)
      end
    end

    desc 'Run all pending batched migrations'
    task execute_batched_migrations: :environment do
      Gitlab::Database::EachDatabase.each_database_connection do |connection, name|
        Gitlab::Database::BackgroundMigration::BatchedMigration.with_status(:active).queue_order.each do |migration|
          Gitlab::AppLogger.info("Executing batched migration #{migration.id} on database #{name} inline")
          Gitlab::Database::BackgroundMigration::BatchedMigrationRunner.new(connection: connection).run_entire_migration(migration)
        end
      end
    end

    desc 'Run migration as gitlab non-superuser'
    task :reset_as_non_superuser, [:username] => :environment do |_, args|
      username = args.fetch(:username, 'gitlab')
      puts "Migrate using username #{username}"
      Rake::Task['db:drop'].invoke
      Rake::Task['db:create'].invoke
      ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env).each do |db_config|
        config = ActiveRecord::DatabaseConfigurations::HashConfig.new(
          db_config.env_name,
          db_config.name,
          db_config.configuration_hash.merge(username: username)
        )

        ActiveRecord::Base.establish_connection(config) # rubocop: disable Database/EstablishConnection
        Gitlab::Database.check_for_non_superuser
        Rake::Task['db:migrate'].invoke
      end
    end

    # Only for development environments,
    # we execute pending data migrations inline for convenience.
    Rake::Task['db:migrate'].enhance do
      if Rails.env.development? && Gitlab::Database::BackgroundMigration::BatchedMigration.table_exists?
        Rake::Task['gitlab:db:execute_batched_migrations'].invoke
      end
    end

    namespace :dictionary do
      DB_DOCS_PATH = File.join(Rails.root, 'db', 'docs')

      desc 'Generate database docs yaml'
      task generate: :environment do
        FileUtils.mkdir_p(DB_DOCS_PATH) unless Dir.exist?(DB_DOCS_PATH)

        Rails.application.eager_load!

        tables = Gitlab::Database.database_base_models.flat_map { |_, m| m.connection.tables }
        classes = tables.to_h { |t| [t, []] }

        Gitlab::Database.database_base_models.each do |_, model_class|
          model_class
            .descendants
            .reject(&:abstract_class)
            .reject { |c| c.name =~ /^(?:EE::)?Gitlab::(?:BackgroundMigration|DatabaseImporters)::/ }
            .reject { |c| c.name =~ /^HABTM_/ }
            .each { |c| classes[c.table_name] << c.name if classes.has_key?(c.table_name) }
        end

        version = Gem::Version.new(File.read('VERSION'))
        milestone = version.release.segments[0..1].join('.')

        tables.each do |table_name|
          file = File.join(DB_DOCS_PATH, "#{table_name}.yml")

          table_metadata = {
            'table_name' => table_name,
            'classes' => classes[table_name]&.sort&.uniq,
            'feature_categories' => [],
            'description' => nil,
            'introduced_by_url' => nil,
            'milestone' => milestone
          }

          if File.exist?(file)
            outdated = false

            existing_metadata = YAML.safe_load(File.read(file))

            if existing_metadata['table_name'] != table_metadata['table_name']
              existing_metadata['table_name'] = table_metadata['table_name']
              outdated = true
            end

            if existing_metadata['classes'].difference(table_metadata['classes']).any?
              existing_metadata['classes'] = table_metadata['classes']
              outdated = true
            end

            File.write(file, existing_metadata.to_yaml) if outdated
          else
            File.write(file, table_metadata.to_yaml)
          end
        end
      end

      # Temporary disable this, see https://gitlab.com/gitlab-org/gitlab/-/merge_requests/85760#note_998452069
      # Rake::Task['db:migrate'].enhance do
      #   Rake::Task['gitlab:db:dictionary:generate'].invoke if Rails.env.development?
      # end
    end
  end
end
