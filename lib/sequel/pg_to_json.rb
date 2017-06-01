require "active_support/core_ext/string/inflections"

module Sequel
  module Plugins
    module PgToJson
      module ClassMethods
        def to_json opts={}
          self.dataset.to_json opts
        end
        def json_attributes *props
          props.each do |prop|
            if prop.respond_to?(:to_sym) and prop = prop.to_sym and self.columns.include?(prop)
              _json_attrs << prop
            elsif prop.is_a? Hash
              prop.keys.each do |p|
                _json_attrs << p  if p.respond_to?(:to_sym) and p = p.to_sym and self.columns.include?(p)
              end
              _json_attr_options.merge! prop
            end
          end
        end
        def json_associations *assocs
          assocs.each do |assoc|
            if assoc.respond_to?(:to_sym) and assoc = assoc.to_sym and self.associations.include?(assoc)
              _json_assocs << assoc
            elsif assoc.is_a? Hash
              assoc.keys.each do |a|
                _json_assocs << a  if a.respond_to?(:to_sym) and a = a.to_sym and self.associations.include?(a)
              end
              _json_assoc_options.merge! assoc
            end
          end
        end
        def _json_assocs
          @json_assocs ||= []
        end
        def _json_assoc_options
          @json_assoc_options ||= {}
        end
        def _json_attrs
          @json_attrs ||= []
        end
        def _json_attr_options
          @json_attr_options ||= {}
        end
      end
      module DatasetMethods
        def to_json opts={}
          opts = { associations: true }.merge(opts)
          ds = self
          if opts[:associations]
            self.model._json_assocs.each do |assoc|
              r = ds.model.association_reflection(assoc)
              m = r[:class_name].split('::').reject { |c| c.empty? }.inject(Object) {|o,c| o.const_get c}
              s = (self.model._json_assoc_options[assoc] and self.model._json_assoc_options[assoc][:ids_only]) ? [m.primary_key] : m._json_attrs
              if k = r[:key] and m.columns.include?(k) and s.any? and not s.include?(k)
                s.push(k)
              end
              if k = m.primary_key and s.any? and not s.include?(k)
                s.push(k)
              end
              ds = ds.eager_graph(assoc => proc{|ads| ads.select(*s) })
            end
          end
          if self.model._json_attrs.any?
            s  = self.model._json_attrs
            s << self.model.primary_key unless s.include?(self.model.primary_key)
            ds = ds.select{s.map{|c|`#{ds.model.table_name}.#{c}`}}
          else
            ds = ds.select{`#{ds.model.table_name}.*`}
          end
          if opts[:associations]
            g = (s || self.columns).map{|c| "#{ds.model.table_name}.#{c}"}
            self.model._json_assocs.each do |assoc|
              r = ds.model.association_reflection(assoc)
              m = r[:class_name].split('::').reject { |c| c.empty? }.inject(Object) {|o,c| o.const_get c}
              if r[:cartesian_product_number] == 0
                if self.model._json_assoc_options[assoc] and self.model._json_assoc_options[assoc][:ids_only]
                  ds = ds.select_append{`\"#{assoc}\".\"#{m.primary_key}\"`.as("#{assoc}_id")}
                  g << "\"#{assoc}\".id"
                else
                  ds = ds.select_append{row_to_json(`\"#{assoc}\"`).as(assoc)}
                  g << "\"#{assoc}\".*"
                end
              else
                if self.model._json_assoc_options[assoc] and self.model._json_assoc_options[assoc][:ids_only]
                  ds = ds.select_append{array_to_json(array_agg(`\"#{assoc}\".\"#{m.primary_key}\"`)).as("#{assoc.to_s.singularize}_ids")}
                else
                  ds = ds.select_append{array_to_json(array_agg(`\"#{assoc}\"`)).as(assoc)}
                end
              end
            end
            ds = ds.group{g.map{|c| `#{c}`}}
          end
          json = ds.from_self(alias: :row).get{array_to_json(array_agg(row_to_json(row)))}
          return json ? json.gsub('[null]', '[]') : '[]'
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
            if self.class._json_assoc_options[assoc] and self.class._json_assoc_options[assoc][:ids_only]
              if obj.is_a?(Array)
                vals["#{assoc.to_s.singularize}_ids"] = obj.map{ |o| o.send(o.primary_key) }
              else
                vals["#{assoc}_id"] = obj.send(obj.primary_key)
              end
            else
              vals[assoc] = obj.is_a?(Array) ? obj.map(&:select_json_values) : obj.select_json_values
            end
          end
          vals.to_json(opts)
        end
      end
    end
  end
end
