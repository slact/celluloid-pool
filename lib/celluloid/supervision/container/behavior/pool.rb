require 'set'

module Celluloid

  module ClassMethods

    # Create a new pool of workers. Accepts the following options:
    #
    # * size: how many workers to create. Default is worker per CPU core
    # * args: array of arguments to pass when creating a worker
    #
    def pool(config={})
      Celluloid.services.supervise(config.merge({
            :type => Supervision::Container::Behavior::Pool,
            :workers => self
          }
        )
      )
    end

    # Same as pool, but links to the pool manager
    def pool_link(klass,config={})
      Supervision::Container::Behavior::Pool.new_link(
        config.merge(:workers => klass)
      )
    end
  end

  module Supervision
    class Container

      def pool(klass, config={})
        Celluloid.services.supervise(config.merge({
              :type => Supervision::Container::Behavior::Pool,
              :workers => klass
            }
          )
        )
      end

      class Instance
        attr_accessor :pool, :pool_size
      end

      class << self
        # Register a pool of actors to be launched on group startup
        def pool(klass, *args, &block)
          blocks << lambda do |container|
            container.pool(Configuration.options(args, :type => klass))
          end
        end
      end

      class Pool

        include Behavior

        identifier! :size, :pool

        configuration {
          @supervisor = Behavior::Pool
          @method = "pool_link"
          @pool = true
          @pool_size = @cofiguration[:size]
          @configuration
        }

      end

      module Behavior
        # Manages a fixed-size pool of workers
        # Delegates work (i.e. methods) and supervises workers
        # Don't use this class directly. Instead use MyKlass.pool
        class Pool
          include Celluloid
          trap_exit :__crash_handler__
          finalizer :__shutdown__

          def initialize(options={})
            @idle = []
            @busy = []
            @workers = options[:workers]
            @args = {}
            @size = 0

            options = Supervision::Configuration.options(options)
            @size = options[:size] || [Celluloid.cores || 2, 2].max
            @args = options[:args] ? Array(options[:args]) : []

            raise ArgumentError, "minimum pool size is 2" if @size < 2

            # Do this last since it can suspend and/or crash
            @idle = @size.times.map { workers.new_link(*@args) }
          end

          def __shutdown__
            # TODO: these can be nil if initializer crashes
            terminators = (@idle + @busy).map do |actor|
              begin
                actor.future(:terminate)
              rescue DeadActorError
              end
            end

            terminators.compact.each { |terminator| terminator.value rescue nil }
          end

          def _send_(method, *args, &block)
            worker = __provision_worker__

            begin
              worker._send_ method, *args, &block
            rescue DeadActorError # if we get a dead actor out of the pool
              wait :respawn_complete
              worker = __provision_worker__
              retry
            rescue Exception => ex
              abort ex
            ensure
              if worker.alive?
                @idle << worker
                @busy.delete worker

                # Broadcast that worker is done processing and
                # waiting idle
                signal :worker_idle
              end
            end
          end

          def name
            _send_ @mailbox, :name
          end

          def is_a?(klass)
            _send_ :is_a?, klass
          end

          def kind_of?(klass)
            _send_ :kind_of?, klass
          end

          def methods(include_ancestors = true)
            _send_ :methods, include_ancestors
          end

          def to_s
            _send_ :to_s
          end

          def inspect
            _send_ :inspect
          end

          def size
            @size
          end

          def size=(new_size)
            new_size = [0, new_size].max

            if new_size > size
              delta = new_size - size
              delta.times { @idle << @workers.new_link(*@args) }
            else
              (size - new_size).times do
                worker = __provision_worker__
                unlink worker
                @busy.delete worker
                worker.terminate
              end
            end
            @size = new_size
          end

          def busy_size
            @busy.length
          end

          def idle_size
            @idle.length
          end

          # Provision a new worker
          def __provision_worker__
            Task.current.guard_warnings = true
            while @idle.empty?
              # Wait for responses from one of the busy workers
              response = exclusive { receive { |msg| msg.is_a?(Internals::Response) } }
              Thread.current[:celluloid_actor].handle_message(response)
            end

            worker = @idle.shift
            @busy << worker

            worker
          end

          # Spawn a new worker for every crashed one
          def __crash_handler__(actor, reason)
            @busy.delete actor
            @idle.delete actor
            return unless reason

            @idle << @workers.new_link(*@args)
            signal :respawn_complete
          end

          def respond_to?(meth, include_private = false)
            # NOTE: use method() here since this class
            # shouldn't be used directly, and method() is less
            # likely to be "reimplemented" inconsistently
            # with other Object.*method* methods.

            found = method(meth)
            if include_private
              found ? true : false
            else
              if found.is_a?(UnboundMethod)
                found.owner.public_instance_methods.include?(meth) ||
                  found.owner.protected_instance_methods.include?(meth)
              else
                found.receiver.public_methods.include?(meth) ||
                  found.receiver.protected_methods.include?(meth)
              end
            end
          rescue NameError
            false
          end

          def method_missing(method, *args, &block)
            if respond_to?(method)
              _send_ method, *args, &block
            else
              super
            end
          end

          # Since Pool allocates worker objects only just before calling them,
          # we can still help Celluloid::Call detect passing invalid parameters to
          # async methods by checking for those methods on the worker class
          def method(meth)
            super
          rescue NameError
            @workers.instance_method(meth.to_sym)
          end
        end
      end
    end
  end
end