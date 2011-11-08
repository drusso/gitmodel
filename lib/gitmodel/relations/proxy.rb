module GitModel
  module Relations
    class Proxy

      attr_reader :relation
      attr_accessor :owner, :target

      def initialize(owner, relation, target=nil)
        @owner, @relation, @target = owner, relation, target
      end

      def get; end
      def set(target); end
      def replace(target); end

    end
  end
end
