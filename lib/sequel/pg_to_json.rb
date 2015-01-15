module Sequel
  module Plugins
    module PgToJson
      module DatasetMethods
        def to_json
          self.db["SELECT array_to_json(array_agg(row_to_json(row))) FROM (#{self.sql}) as row"].all[0][:array_to_json]
        end
      end
    end
  end
end
