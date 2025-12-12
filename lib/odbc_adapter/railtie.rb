# Railtie for ODBC adapter Rails integration
# This ensures Rails-specific patches are applied when Rails is loaded

if defined?(Rails)
  module ODBCAdapter
    class Railtie < Rails::Railtie
      # Run after Rails is initialized
      config.after_initialize do
        # Skip migration checks for ODBC connections
        # The ODBC driver has a bug where it incorrectly detects null bytes in clean strings
        if defined?(ActiveRecord::Migration::CheckPending)
          ActiveRecord::Migration::CheckPending.class_eval do
            alias_method :original_call, :call unless method_defined?(:original_call)
            
            def call(env)
              # Always wrap the original call in error handling to catch null byte errors
              begin
                # Check if primary connection is ODBC adapter
                if ActiveRecord::Base.connection.is_a?(ActiveRecord::ConnectionAdapters::ODBCAdapter)
                  # Skip migration checks for ODBC adapters due to driver bug
                  @app.call(env)
                else
                  # Try original call, but catch null byte errors
                  original_call(env)
                end
              rescue ArgumentError => e
                if e.message.include?("null byte")
                  # If we get a null byte error, it's likely the ODBC driver bug
                  Rails.logger.warn("Skipping migration check due to null byte error (ODBC driver bug): #{e.message}") if Rails.logger
                  @app.call(env)
                else
                  raise
                end
              rescue => e
                # For any other error during migration check, log and continue
                Rails.logger.warn("Skipping migration check due to error: #{e.class} - #{e.message}") if Rails.logger
                @app.call(env)
              end
            end
          end
        end
      end
    end
  end
end

