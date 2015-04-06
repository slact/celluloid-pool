module Celluloid
  class SupervisionGroup
    class << self

      # Register a pool of actors to be launched on group startup
      def pool(klass, *args, &block)
        blocks << lambda do |group|
          group.pool(klass, prepare_options(args, :block => block))
        end
      end

    end

    def pool(klass, options = {})
      puts "#{[ klass, options ]}"
      options[:method] = 'pool_link'
      options[:injections] = {
        # when it is a pool, then we don't splat the args
        # and we need to extract the pool size if set
        :start => Proc.new {
          if @pool
            options = {:args => @args}
            options[:size] = @pool_size if @pool_size
            @args = [options]
          end
        },
        :initialize => Proc.new {
          @pool = @method == 'pool_link'
          @pool_size = @options['size'] if @pool
        }
      }
      add(klass, options)
    end

    class Member
      attr_accessor :pool, :pool_size
    end

  end
end