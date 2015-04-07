RSpec.describe Celluloid::SupervisionGroup, actor_system: :global do

  class SupervisionGroupHelper
    QUEUE = Queue.new
    SIZE = ::POOL_SIZE
  end

  class MyPoolActor
    include Celluloid

    attr_reader :args
    def initialize *args
      @args = *args
      ready
    end

    def running?
      :yep
    end

    def ready
      SupervisionGroupHelper::QUEUE << :done
    end
  end

  context "when supervising a pool" do
    let(:size) { SupervisionGroupHelper::SIZE }

    before do
      subject
      size.times { SupervisionGroupHelper::QUEUE.pop }
    end

    subject do
      Class.new(Celluloid::SupervisionGroup) do
        pool MyPoolActor, :as => :example_pool, :args => 'foo', :size => SupervisionGroupHelper::SIZE
      end.run!
    end

    it "runs applications and passes pool options and actor args" do
      expect(Celluloid::Actor[:example_pool]).to be_running
      expect(Celluloid::Actor[:example_pool].args).to eq ['foo']
      expect(Celluloid::Actor[:example_pool].size).to be size
    end
  end
end
