# Requiring with this pattern to mirror ActiveRecord
require 'active_record/connection_adapters/odbc_adapter'

# Load Rails integration (Railtie)
# This handles Rails-specific patches like skipping migration checks for ODBC connections
# The Railtie file itself checks if Rails is available
begin
  require_relative 'odbc_adapter/railtie'
rescue LoadError
  # Railtie file might not exist in all environments
  # This is okay, the adapter will still work without it
end
