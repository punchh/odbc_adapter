module ODBCAdapter
  module SchemaStatements
    # Returns a Hash of mappings from the abstract data types to the native
    # database types. See TableDefinition#column for details on the recognized
    # abstract data types.
    def native_database_types
      @native_database_types ||= ColumnMetadata.new(self).native_database_types
    end

    # Returns an array of table names, for database tables visible on the
    # current connection.
    # Override to return empty array for performance (e.g., Databricks/Snowflake)
    # when schema introspection is not needed or causes issues
    def tables(_name = nil)
      # Return empty array to avoid expensive schema introspection calls
      # This is particularly useful for Databricks/Snowflake where schema
      # introspection can be slow or cause connection issues
      []
    end

    # Returns an array of view names defined in the database.
    def views
      []
    end

    # Returns an array of indexes for the given table.
    def indexes(table_name, _name = nil)
      stmt   = @connection.indexes(native_case(table_name.to_s))
      result = stmt.fetch_all || []
      stmt.drop unless stmt.nil?

      index_cols = []
      index_name = nil
      unique     = nil

      result.each_with_object([]).with_index do |(row, indices), row_idx|
        # Skip table statistics
        next if row[6].zero? # SQLStatistics: TYPE

        if row[7] == 1 # SQLStatistics: ORDINAL_POSITION
          # Start of column descriptor block for next index
          index_cols = []
          unique     = row[3].zero? # SQLStatistics: NON_UNIQUE
          index_name = String.new(row[5]) # SQLStatistics: INDEX_NAME
        end

        index_cols << format_case(row[8]) # SQLStatistics: COLUMN_NAME
        next_row = result[row_idx + 1]

        if (row_idx == result.length - 1) || (next_row[6].zero? || next_row[7] == 1)
          indices << ActiveRecord::ConnectionAdapters::IndexDefinition.new(table_name, format_case(index_name), unique, index_cols)
        end
      end
    end

    # Returns an array of Column objects for the table specified by
    # +table_name+.
    # Override to return empty array for performance (e.g., Databricks/Snowflake)
    # when schema introspection is not needed or causes issues
    def columns(table_name, _name = nil)
      # Return empty array to avoid expensive schema introspection calls
      # This is particularly useful for Databricks/Snowflake where schema
      # introspection can be slow or cause connection issues
      []
    end
    
    # Override type_to_sql to handle Databricks string types
    # Databricks doesn't support STRING(20000) syntax, use STRING without length
    def type_to_sql(type, limit: nil, precision: nil, scale: nil, **options)
      # For string types, ignore the limit and use STRING without length
      # This is required for Databricks/Spark SQL compatibility
      if type == :string || type.to_s == 'string'
        return "STRING"
      end
      # Call super for all other types
      super
    end

    # Returns just a table's primary key
    def primary_key(table_name)
      stmt   = @connection.primary_keys(native_case(table_name.to_s))
      result = stmt.fetch_all || []
      stmt.drop unless stmt.nil?
      result[0] && result[0][3]
    end

    def foreign_keys(table_name)
      stmt   = @connection.foreign_keys(native_case(table_name.to_s))
      result = stmt.fetch_all || []
      stmt.drop unless stmt.nil?

      result.map do |key|
        fk_from_table      = key[2]  # PKTABLE_NAME
        fk_to_table        = key[6]  # FKTABLE_NAME

        ActiveRecord::ConnectionAdapters::ForeignKeyDefinition.new(
          fk_from_table,
          fk_to_table,
          name:        key[11], # FK_NAME
          column:      key[3],  # PKCOLUMN_NAME
          primary_key: key[7],  # FKCOLUMN_NAME
          on_delete:   key[10], # DELETE_RULE
          on_update:   key[9]   # UPDATE_RULE
        )
      end
    end

    # Ensure it's shorter than the maximum identifier length for the current
    # dbms
    def index_name(table_name, options)
      maximum = database_metadata.max_identifier_len || 255
      super(table_name, options)[0...maximum]
    end

    def current_database
      database_metadata.database_name.strip
    end
  end
end
