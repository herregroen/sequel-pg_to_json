module Sequel
  module Plugins
    module PgToJson
      module ClassMethods
        def to_json
          self.dataset.to_json
        end
        def json_attributes *props
          props.each do |prop|
            if prop.respond_to?(:to_sym) and prop = prop.to_sym and self.columns.include?(prop)
              _json_attrs << prop
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
        def _json_attrs
          @json_attrs ||= []
        end
      end
      module DatasetMethods
        def to_json opts={}
          opts = { associations: true }.merge(opts)
          ds = self
          if opts[:associations]
            self.model._json_assocs.each do |assoc|
              r = ds.model.association_reflection(assoc)
              m = r[:class_name].split('::').inject(Object) {|o,c| o.const_get c}
              s = m._json_attrs
              s << k if k = r[:key] and m.columns.include?(k) and s.any? and not s.include?(k)
              s << k if k = m.primary_key and s.any? and not s.include?(k)
              ds = ds.eager_graph(assoc => proc{|ads| ads.select(*s) })
            end
          end
          if self.model._json_attrs.any?
            s  = self.model._json_attrs
            s << self.model.primary_key unless s.include?(self.model.primary_key)
            ds = ds.select{s.map{|p|`#{ds.model.table_name}.#{p}`}}
          else
            ds = ds.select{`#{ds.model.table_name}.*`}
          end
          if opts[:associations]
            g = ["#{self.model.table_name}.#{self.model.primary_key}"]
            self.model._json_assocs.each do |assoc|
              r = ds.model.association_reflection(assoc)
              if r[:cartesian_product_number] == 0
                ds = ds.select_append{row_to_json(`\"#{assoc}\"`).as(assoc)}
                g << "\"#{assoc}\".*"
              else
                ds = ds.select_append{array_to_json(array_agg(`\"#{assoc}\"`)).as(assoc)}
              end
            end
            ds = ds.group{g.map{|c| `#{c}`}}
          end
          ds.from_self(alias: :row).get{array_to_json(array_agg(row_to_json(row)))}.gsub('[null]','[]')
        end
      end
      module InstanceMethods
        def select_json_values
          vals = self.values
          vals = vals.select { |k| self.class._json_attrs.include?(k) } if self.class._json_attrs.any?
          return vals
        end
        def to_json opts={}
          vals = select_json_values
          self.class._json_assocs.each do |assoc|
            obj = send(assoc)
            vals[assoc] = obj.is_a?(Array) ? obj.map(&:select_json_values) : obj.select_json_values
          end
          vals.to_json(opts)
        end
      end
    end
  end
end
