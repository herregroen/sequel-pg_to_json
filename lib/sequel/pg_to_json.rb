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
              _json_props << prop
            end
          end
        end
        def json_associations *assocs
          assocs.each do |assoc|
            if assoc.respond_to?(:to_sym) and assoc = assoc.to_sym and self.associations.include?(assoc)
              _json_assocs << assoc
            end
          end
        end
        def _json_assocs
          @json_assocs ||= []
        end
        def _json_props
          @json_props ||= []
        end
      end
      module DatasetMethods
        def to_json opts={}
          g = ["#{self.model.table_name}.#{self.model.primary_key}"]
          if self.model._json_props.any?
            s  = self.model._json_props
            s << self.model.primary_key unless s.include?(self.model.primary_key)
            ds = self.select{s.map{|p|`#{self.model.table_name}.#{p}`}}
          else
            ds = self.select{`#{self.model.table_name}.*`}
          end
          self.model._json_assocs.each do |assoc|
            r = self.model.association_reflection(assoc)
            s = r[:model]._json_props
            s << k if k = r[:key] and m.columns.include?(k) and s.any? and not s.include?(k)
            ds.eager_graph(assoc => proc{|ads| ads.select(*s) })
            if r[:cartesian_product_number] == 0
              ds = ds.select_append{array_to_json(array_agg(`\"#{assoc}\"`)).as(assoc)}
            else
              ds = ds.select_append{row_to_json(`\"#{assoc}\"`).as(assoc)}
              g << "\"#{assoc}\".*"
            end
          end
          ds.from_self(alias: :row).select{array_to_json(array_agg(row))}.all[0][:array_to_json] || '[]'
          # sql = self.select(*self.model._json_props).sql
#           self.db["SELECT array_to_json(array_agg(row_to_json(row))) FROM (#{sql}) as row"].all[0][:array_to_json] || '[]'
        end
      end
      module InstanceMethods
        def to_json opts={}
          vals = self.values
          vals = vals.select { |k| self.class._json_props.include?(k) } if self.class._json_props.any?
          vals.to_json(opts)
        end
      end
    end
  end
end
