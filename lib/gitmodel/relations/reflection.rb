module GitModel
  module Relations

    class Reflection
      attr_reader :model, :name, :inverse, :foreign_key

      def initialize(model, name, options={})
        @model       = model
        @name        = name
        @type        = options[:class_name] || @name.to_s.classify
        @inverse     = options[:inverse_of] || @model.to_s.tableize.singularize.to_sym
        @foreign_key = options[:foreign_key] || default_foreign_key
      end

      def type
        @type.constantize
      end

      def stores_foreign_key?
        !!foreign_key
      end

    end

  end
end
