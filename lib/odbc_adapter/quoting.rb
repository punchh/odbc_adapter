module ODBCAdapter
  module Quoting
    # Class methods for Rails 8 compatibility
    # Rails 8 requires these as class methods in addition to instance methods
    module ClassMethods
      def quote_column_name(name)
        # Use backticks for Databricks/Spark SQL identifiers
        # Escape backticks by doubling them
        %Q(`#{name.to_s.gsub('`', '``')}`)
      end

      def quote_table_name(name)
        # Use backticks for Databricks/Spark SQL identifiers
        # Escape backticks by doubling them
        %Q(`#{name.to_s.gsub('`', '``')}`)
      end
    end
    
    # Quotes a string, escaping any ' (single quote) characters.
    def quote_string(string)
      string.gsub(/\'/, "''")
    end

    # Returns a quoted form of the column name.
    # Override to use backticks for Databricks/Spark SQL compatibility
    def quote_column_name(name)
      # Use backticks for Databricks/Spark SQL identifiers
      # Escape backticks by doubling them
      %Q(`#{name.to_s.gsub('`', '``')}`)
    end

    # Ideally, we'd return an ODBC date or timestamp literal escape
    # sequence, but not all ODBC drivers support them.
    def quoted_date(value)
      if value.acts_like?(:time)
        zone_conversion_method = ActiveRecord::Base.default_timezone == :utc ? :getutc : :getlocal

        if value.respond_to?(zone_conversion_method)
          value = value.send(zone_conversion_method)
        end
        value.strftime('%Y-%m-%d %H:%M:%S') # Time, DateTime
      else
        value.strftime('%Y-%m-%d') # Date
      end
    end
    
    # Returns a quoted form of the table name.
    # Override to use backticks for Databricks/Spark SQL compatibility
    def quote_table_name(name)
      # Use backticks for Databricks/Spark SQL identifiers
      # Escape backticks by doubling them
      %Q(`#{name.to_s.gsub('`', '``')}`)
    end
  end
end
