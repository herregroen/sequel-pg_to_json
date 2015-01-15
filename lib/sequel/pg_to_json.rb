module Sequel
  module Plugins
    module PgToJson
      module ClassMethods
        def to_json
          self.dataset.to_json
        end
        def json_properties *props
          props.each do |prop|
            if prop.respond_to?(:to_sym) and prop = prop.to_sym and self.columns.include?(prop)
              json_props << prop
            end
          end
        end
        def json_props
          @json_props ||= []
        end
      end
      module DatasetMethods
        def to_json opts={}
          sql = self.select(*self.model.json_props).sql
          self.db["SELECT array_to_json(array_agg(row_to_json(row))) FROM (#{sql}) as row"].all[0][:array_to_json]
        end
      end
      module InstanceMethods
        def to_json opts={}
          vals = self.values
          vals = vals.select { |k| self.class.json_props.include?(k) } if self.class.json_props.any?
          vals.to_json(opts)
        end
      end
    end
  end
end
