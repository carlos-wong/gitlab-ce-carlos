# frozen_string_literal: true

module Gitlab
  module Database
    module MigrationHelpers
      module V2
        include Gitlab::Database::MigrationHelpers

        # Superseded by `create_table` override below
        def create_table_with_constraints(*_)
          raise <<~EOM
            #create_table_with_constraints is not supported anymore - use #create_table instead, for example:

              create_table :db_guides do |t|
                t.bigint :stars, default: 0, null: false
                t.text :title, limit: 128
                t.text :notes, limit: 1024

                t.check_constraint 'stars > 1000', name: 'so_many_stars'
              end

            See https://docs.gitlab.com/ee/development/database/strings_and_the_text_data_type.html
          EOM
        end

        # Creates a new table, optionally allowing the caller to add text limit constraints to the table.
        # This method only extends Rails' `create_table` method
        #
        # Example:
        #
        #    create_table :db_guides do |t|
        #      t.bigint :stars, default: 0, null: false
        #      t.text :title, limit: 128
        #      t.text :notes, limit: 1024
        #
        #      t.check_constraint 'stars > 1000', name: 'so_many_stars'
        #    end
        #
        # See Rails' `create_table` for more info on the available arguments.
        #
        # When adding foreign keys to other tables, consider wrapping the call into a with_lock_retries block
        # to avoid traffic stalls.
        def create_table(table_name, *args, **kwargs, &block)
          helper_context = self

          super do |t|
            t.define_singleton_method(:text) do |column_name, **kwargs|
              limit = kwargs.delete(:limit)

              super(column_name, **kwargs)

              if limit
                # rubocop:disable GitlabSecurity/PublicSend
                name = helper_context.send(:text_limit_name, table_name, column_name)
                # rubocop:enable GitlabSecurity/PublicSend

                column_name = helper_context.quote_column_name(column_name)
                definition = "char_length(#{column_name}) <= #{limit}"

                t.check_constraint(definition, name: name)
              end
            end

            t.instance_eval(&block) unless block.nil?
          end
        end

        # Executes the block with a retry mechanism that alters the +lock_timeout+ and +sleep_time+ between attempts.
        # The timings can be controlled via the +timing_configuration+ parameter.
        # If the lock was not acquired within the retry period, a last attempt is made without using +lock_timeout+.
        #
        # In order to retry the block, the method wraps the block into a transaction.
        #
        # When called inside an open transaction it will execute the block directly if lock retries are enabled
        # with `enable_lock_retries!` at migration level, otherwise it will raise an error.
        #
        # ==== Examples
        #   # Invoking without parameters
        #   with_lock_retries do
        #     drop_table :my_table
        #   end
        #
        #   # Invoking with custom +timing_configuration+
        #   t = [
        #     [1.second, 1.second],
        #     [2.seconds, 2.seconds]
        #   ]
        #
        #   with_lock_retries(timing_configuration: t) do
        #     drop_table :my_table # this will be retried twice
        #   end
        #
        #   # Disabling the retries using an environment variable
        #   > export DISABLE_LOCK_RETRIES=true
        #
        #   with_lock_retries do
        #     drop_table :my_table # one invocation, it will not retry at all
        #   end
        #
        # ==== Parameters
        # * +timing_configuration+ - [[ActiveSupport::Duration, ActiveSupport::Duration], ...] lock timeout for the block, sleep time before the next iteration, defaults to `Gitlab::Database::WithLockRetries::DEFAULT_TIMING_CONFIGURATION`
        # * +logger+ - [Gitlab::JsonLogger]
        # * +env+ - [Hash] custom environment hash, see the example with `DISABLE_LOCK_RETRIES`
        def with_lock_retries(*args, **kwargs, &block)
          if transaction_open?
            if enable_lock_retries?
              Gitlab::AppLogger.warn 'Lock retries already enabled, executing the block directly'
              yield
            else
              raise <<~EOF
              #{__callee__} can not be run inside an already open transaction

              Use migration-level lock retries instead, see https://docs.gitlab.com/ee/development/migration_style_guide.html#retry-mechanism-when-acquiring-database-locks
              EOF
            end
          else
            super(*args, **kwargs.merge(allow_savepoints: false), &block)
          end
        end

        # Renames a column without requiring downtime.
        #
        # Concurrent renames work by using database triggers to ensure both the
        # old and new column are in sync. However, this method will _not_ remove
        # the triggers or the old column automatically; this needs to be done
        # manually in a post-deployment migration. This can be done using the
        # method `cleanup_concurrent_column_rename`.
        #
        # table - The name of the database table containing the column.
        # old_column - The old column name.
        # new_column - The new column name.
        # type - The type of the new column. If no type is given the old column's
        #        type is used.
        # batch_column_name - option is for tables without primary key, in this
        #        case another unique integer column can be used. Example: :user_id
        def rename_column_concurrently(table, old_column, new_column, type: nil, batch_column_name: :id)
          Gitlab::Database::QueryAnalyzers::RestrictAllowedSchemas.require_ddl_mode!

          setup_renamed_column(__callee__, table, old_column, new_column, type, batch_column_name)

          with_lock_retries do
            install_bidirectional_triggers(table, old_column, new_column)
          end
        end

        # Reverses operations performed by rename_column_concurrently.
        #
        # This method takes care of removing previously installed triggers as well
        # as removing the new column.
        #
        # table - The name of the database table.
        # old_column - The name of the old column.
        # new_column - The name of the new column.
        def undo_rename_column_concurrently(table, old_column, new_column)
          teardown_rename_mechanism(table, old_column, new_column, column_to_remove: new_column)
        end

        # Cleans up a concurrent column name.
        #
        # This method takes care of removing previously installed triggers as well
        # as removing the old column.
        #
        # table - The name of the database table.
        # old_column - The name of the old column.
        # new_column - The name of the new column.
        def cleanup_concurrent_column_rename(table, old_column, new_column)
          teardown_rename_mechanism(table, old_column, new_column, column_to_remove: old_column)
        end

        # Reverses the operations performed by cleanup_concurrent_column_rename.
        #
        # This method adds back the old_column removed
        # by cleanup_concurrent_column_rename.
        # It also adds back the triggers that are removed
        # by cleanup_concurrent_column_rename.
        #
        # table - The name of the database table containing the column.
        # old_column - The old column name.
        # new_column - The new column name.
        # type - The type of the old column. If no type is given the new column's
        #        type is used.
        # batch_column_name - option is for tables without primary key, in this
        #        case another unique integer column can be used. Example: :user_id
        #
        def undo_cleanup_concurrent_column_rename(table, old_column, new_column, type: nil, batch_column_name: :id)
          Gitlab::Database::QueryAnalyzers::RestrictAllowedSchemas.require_ddl_mode!

          setup_renamed_column(__callee__, table, new_column, old_column, type, batch_column_name)

          with_lock_retries do
            install_bidirectional_triggers(table, old_column, new_column)
          end
        end

        private

        def setup_renamed_column(calling_operation, table, old_column, new_column, type, batch_column_name)
          if transaction_open?
            raise "#{calling_operation} can not be run inside a transaction"
          end

          column = columns(table).find { |column| column.name == old_column.to_s }

          unless column
            raise "Column #{old_column} does not exist on #{table}"
          end

          if column.default
            raise "#{calling_operation} does not currently support columns with default values"
          end

          unless column_exists?(table, batch_column_name)
            raise "Column #{batch_column_name} does not exist on #{table}"
          end

          check_trigger_permissions!(table)

          unless column_exists?(table, new_column)
            create_column_from(table, old_column, new_column, type: type, batch_column_name: batch_column_name)
          end
        end

        def teardown_rename_mechanism(table, old_column, new_column, column_to_remove:)
          return unless column_exists?(table, column_to_remove)

          with_lock_retries do
            check_trigger_permissions!(table)

            remove_bidirectional_triggers(table, old_column, new_column)

            remove_column(table, column_to_remove)
          end
        end

        def install_bidirectional_triggers(table, old_column, new_column)
          insert_trigger_name, update_old_trigger_name, update_new_trigger_name =
            bidirectional_trigger_names(table, old_column, new_column)

          quoted_table = quote_table_name(table)
          quoted_old = quote_column_name(old_column)
          quoted_new = quote_column_name(new_column)

          create_insert_trigger(insert_trigger_name, quoted_table, quoted_old, quoted_new)
          create_update_trigger(update_old_trigger_name, quoted_table, quoted_new, quoted_old)
          create_update_trigger(update_new_trigger_name, quoted_table, quoted_old, quoted_new)
        end

        def remove_bidirectional_triggers(table, old_column, new_column)
          insert_trigger_name, update_old_trigger_name, update_new_trigger_name =
            bidirectional_trigger_names(table, old_column, new_column)

          quoted_table = quote_table_name(table)

          drop_trigger(insert_trigger_name, quoted_table)
          drop_trigger(update_old_trigger_name, quoted_table)
          drop_trigger(update_new_trigger_name, quoted_table)
        end

        def bidirectional_trigger_names(table, old_column, new_column)
          %w[insert update_old update_new].map do |operation|
            'trigger_' + Digest::SHA256.hexdigest("#{table}_#{old_column}_#{new_column}_#{operation}").first(12)
          end
        end

        def function_name_for_trigger(trigger_name)
          "function_for_#{trigger_name}"
        end

        def create_insert_trigger(trigger_name, quoted_table, quoted_old_column, quoted_new_column)
          function_name = function_name_for_trigger(trigger_name)

          execute(<<~SQL)
            CREATE OR REPLACE FUNCTION #{function_name}()
            RETURNS trigger
            LANGUAGE plpgsql
            AS $$
            BEGIN
              IF NEW.#{quoted_old_column} IS NULL AND NEW.#{quoted_new_column} IS NOT NULL THEN
                NEW.#{quoted_old_column} = NEW.#{quoted_new_column};
              END IF;

              IF NEW.#{quoted_new_column} IS NULL AND NEW.#{quoted_old_column} IS NOT NULL THEN
                NEW.#{quoted_new_column} = NEW.#{quoted_old_column};
              END IF;

              RETURN NEW;
            END
            $$;

            DROP TRIGGER IF EXISTS #{trigger_name}
            ON #{quoted_table};

            CREATE TRIGGER #{trigger_name}
            BEFORE INSERT ON #{quoted_table}
            FOR EACH ROW EXECUTE FUNCTION #{function_name}();
          SQL
        end

        def create_update_trigger(trigger_name, quoted_table, quoted_source_column, quoted_target_column)
          function_name = function_name_for_trigger(trigger_name)

          execute(<<~SQL)
            CREATE OR REPLACE FUNCTION #{function_name}()
            RETURNS trigger
            LANGUAGE plpgsql
            AS $$
            BEGIN
              NEW.#{quoted_target_column} := NEW.#{quoted_source_column};
              RETURN NEW;
            END
            $$;

            DROP TRIGGER IF EXISTS #{trigger_name}
            ON #{quoted_table};

            CREATE TRIGGER #{trigger_name}
            BEFORE UPDATE OF #{quoted_source_column} ON #{quoted_table}
            FOR EACH ROW EXECUTE FUNCTION #{function_name}();
          SQL
        end

        def drop_trigger(trigger_name, quoted_table)
          function_name = function_name_for_trigger(trigger_name)

          execute(<<~SQL)
            DROP TRIGGER IF EXISTS #{trigger_name}
            ON #{quoted_table};

            DROP FUNCTION IF EXISTS #{function_name};
          SQL
        end
      end
    end
  end
end
