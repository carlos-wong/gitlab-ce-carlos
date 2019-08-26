namespace :gitlab do
  namespace :db do
    desc 'GitLab | Manually insert schema migration version'
    task :mark_migration_complete, [:version] => :environment do |_, args|
      unless args[:version]
        puts "Must specify a migration version as an argument".color(:red)
        exit 1
      end

      version = args[:version].to_i
      if version == 0
        puts "Version '#{args[:version]}' must be a non-zero integer".color(:red)
        exit 1
      end

      sql = "INSERT INTO schema_migrations (version) VALUES (#{version})"
      begin
        ActiveRecord::Base.connection.execute(sql)
        puts "Successfully marked '#{version}' as complete".color(:green)
      rescue ActiveRecord::RecordNotUnique
        puts "Migration version '#{version}' is already marked complete".color(:yellow)
      end
    end

    desc 'Drop all tables'
    task drop_tables: :environment do
      connection = ActiveRecord::Base.connection

      # In PostgreSQLAdapter, data_sources returns both views and tables, so use
      # #tables instead
      tables = connection.tables

      # Removes the entry from the array
      tables.delete 'schema_migrations'
      # Truncate schema_migrations to ensure migrations re-run
      connection.execute('TRUNCATE schema_migrations') if connection.table_exists? 'schema_migrations'

      # Drop tables with cascade to avoid dependent table errors
      # PG: http://www.postgresql.org/docs/current/static/ddl-depend.html
      # Add `IF EXISTS` because cascade could have already deleted a table.
      tables.each { |t| connection.execute("DROP TABLE IF EXISTS #{connection.quote_table_name(t)} CASCADE") }
    end

    desc 'Configures the database by running migrate, or by loading the schema and seeding if needed'
    task configure: :environment do
      # Check if we have existing db tables
      # The schema_migrations table will still exist if drop_tables was called
      if ActiveRecord::Base.connection.tables.count > 1
        Rake::Task['db:migrate'].invoke
      else
        # Add post-migrate paths to ensure we mark all migrations as up
        Gitlab::Database.add_post_migrate_path_to_rails(force: true)
        Rake::Task['db:schema:load'].invoke
        Rake::Task['db:seed_fu'].invoke
      end
    end

    desc 'Checks if migrations require downtime or not'
    task :downtime_check, [:ref] => :environment do |_, args|
      abort 'You must specify a Git reference to compare with' unless args[:ref]

      require 'shellwords'

      ref = Shellwords.escape(args[:ref])

      migrations = `git diff #{ref}.. --diff-filter=A --name-only -- db/migrate`.lines
        .map { |file| Rails.root.join(file.strip).to_s }
        .select { |file| File.file?(file) }
        .select { |file| /\A[0-9]+.*\.rb\z/ =~ File.basename(file) }

      Gitlab::DowntimeCheck.new.check_and_print(migrations)
    end

    desc 'Sets up EE specific database functionality'

    if Gitlab.ee?
      task setup_ee: %w[geo:db:drop geo:db:create geo:db:schema:load geo:db:migrate]
    else
      task :setup_ee
    end
  end
end
