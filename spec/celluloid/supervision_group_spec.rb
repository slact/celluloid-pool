RSpec.describe Celluloid::SupervisionGroup, actor_system: :global do

  context "pool" do
    before :all do
      class MyPoolActor
        include Celluloid

        attr_reader :args
        def initialize *args
          @args = *args
        end
        def running?; :yep; end
      end
      class MyPoolGroup < Celluloid::SupervisionGroup
        pool MyPoolActor, :as => :example_pool, :args => 'foo', :size => 3
      end
    end

    it "runs applications and passes pool options and actor args" do
      MyPoolGroup.run!
      sleep 0.001 # startup time hax

      expect(Celluloid::Actor[:example_pool]).to be_running
      expect(Celluloid::Actor[:example_pool].args).to eq ['foo']
      expect(Celluloid::Actor[:example_pool].size).to be 3
    end
  end
end