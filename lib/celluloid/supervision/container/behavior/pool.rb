require "set"

module Celluloid
  module ClassMethods
    extend Forwardable
    def_delegators :"Celluloid::Supervision::Container::Pool", :pooling_options
    # Create a new pool of workers. Accepts the following options:
    #
    # * size: how many workers to create. Default is worker per CPU core
    # * args: array of arguments to pass when creating a worker
    #
    def pool(config={})
      Celluloid.services.supervise(pooling_options(config, workers: self))
      Celluloid.services.actors.last
    end

    # Same as pool, but links to the pool manager
    def pool_link(klass, config={})
      Supervision::Container::Pool.new_link(pooling_options(config, workers: klass))
    end
  end

  module Supervision
    class Container
      extend Forwardable
      def_delegators :"Celluloid::Supervision::Container::Pool", :pooling_options
      def pool(klass, config={})
        Celluloid.services.supervise(pooling_options(config, workers: klass))
        Celluloid.services.actors.last
      end

      class Instance
        attr_accessor :pool, :pool_size
      end

      class << self
        # Register a pool of actors to be launched on group startup
        def pool(klass, *args, &_block)
          blocks << lambda do |container|
            container.pool(klass, Configuration.options(args))
          end
        end
      end

      class Pool
        include Behavior

        class << self
          def pooling_options(config={},mixins={})
            combined = { :type => Celluloid::Supervision::Container::Pool }.merge(config).merge(mixins)
            combined[:args] = [combined.select { |k,v| [:workers, :size, :args].include?(k) }]
            combined
          end
        end

        identifier! :size, :pool

        configuration do
          puts "configuring pool"
          @supervisor = Container::Pool
          @method = "pool_link"
          @pool = true
          @pool_size = @cofiguration[:size]
          @configuration
        end
      end

      
    end
  end
end
