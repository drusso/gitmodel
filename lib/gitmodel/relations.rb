require 'gitmodel/relations/proxy'
require 'gitmodel/relations/proxies/to'
require 'gitmodel/relations/proxies/one'
require 'gitmodel/relations/proxies/many'
require 'gitmodel/relations/reflection'
require 'gitmodel/relations/reflections/to'
require 'gitmodel/relations/reflections/one'
require 'gitmodel/relations/reflections/many'

module GitModel
  module Relations
    extend ActiveSupport::Concern

    included do
      attr_accessor :proxies
      class_attribute :relations
      self.relations = {}
    end

    def proxy(name)
      @proxies ||= {}
      @proxies[name] ||= (
        relation = self.class.relations[name]
        relation.proxy.new(self, relation)
      )
    end

    def reset_proxies
      @proxies = {}
    end

    module ClassMethods

      def has_many(name, options={})
        relate Reflections::Many.new(self, name, options)
      end

      def has_one(name, options={})
        relate Reflections::One.new(self, name, options)
      end

      def belongs_to(name, options={})
        relate Reflections::To.new(self, name, options)
      end

      def has_and_belongs_to_many(name, options={})
      end

      private

      def relate(relation)
        relations[relation.name] = relation
        define_method("#{relation.name}") { proxy(relation.name).get }
        define_method("#{relation.name}=") { |target| proxy(relation.name).set(target) }
      end

    end

  end
end
