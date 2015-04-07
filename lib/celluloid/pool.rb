require 'celluloid'
require 'celluloid/pool/manager'
require 'celluloid/pool/supervision_group'

module Celluloid
  module ClassMethods
    # Create a new pool of workers. Accepts the following options:
    #
    # * size: how many workers to create. Default is worker per CPU core
    # * args: array of arguments to pass when creating a worker
    #
    def pool(options={})
      PoolManager.new(self, options)
    end

    # Same as pool, but links to the pool manager
    def pool_link(options={})
      PoolManager.new_link(self, options)
    end
  end
end