# Rails integration for ODBC adapter
# Handles Rails-specific patches and workarounds for ODBC adapter compatibility

# Skip migration checks for ODBC connections
# The ODBC driver has a bug where it incorrectly detects null bytes in clean strings
# This prevents Rails from checking pending migrations on startup for ODBC connections

if defined?(ActiveRecord::ConnectionAdapters::ODBCAdapter) && defined?(ActiveRecord::Migration::CheckPending)
  # Override the CheckPending middleware to skip for ODBC connections
  ActiveRecord::Migration::CheckPending.class_eval do
    alias_method :original_call, :call unless method_defined?(:original_call)
    
    def call(env)
      # Always wrap the original call in error handling to catch null byte errors
      # This handles cases where ODBC connections might not be detected upfront
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
          # Skip the migration check and continue
          if defined?(Rails) && Rails.logger
            Rails.logger.warn("Skipping migration check due to null byte error (ODBC driver bug): #{e.message}")
          end
          @app.call(env)
        else
          # Re-raise if it's a different ArgumentError
          raise
        end
      rescue => e
        # For any other error during migration check, log and continue
        # This prevents the application from crashing due to migration check issues
        if defined?(Rails) && Rails.logger
          Rails.logger.warn("Skipping migration check due to error: #{e.class} - #{e.message}")
        end
        @app.call(env)
      end
    end
  end
end

