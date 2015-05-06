RSpec.describe Celluloid::Supervision::Container, actor_system: :global do
  class SupervisionContainerHelper
    QUEUE = Queue.new

    # Keep it at 3 to better detect argument-passing issues
    SIZE = 3
  end

  class MyPoolActor
    include Celluloid

    attr_reader :args
    def initialize(*args)
      @args = *args
      ready
    end

    def running?
      :yep
    end

    def ready
      SupervisionContainerHelper::QUEUE << :done
    end
  end

  context "when supervising a 3-item pool pool" do
    let(:size) { SupervisionContainerHelper::SIZE }

    before do
      subject

      initialized = 0
      begin
        Timeout.timeout(2) do
          size.times do
            SupervisionContainerHelper::QUEUE.pop
            initialized += 1
          end
        end
      rescue Timeout::Error
        raise "Timeout waiting for all #{size} workers to initialize (got only #{initialized} ready). Arguments handled incorrectly?"
      end
    end

    subject do
      Class.new(Celluloid::Supervision::Container) do
        pool MyPoolActor, as: :example_pool, args: ["foo"], size: SupervisionContainerHelper::SIZE
      end.run!
    end

    it "runs applications and passes pool options and actor args" do
      expect(Celluloid::Actor[:example_pool]).to be_running
      expect(Celluloid::Actor[:example_pool].args).to eq ["foo"]
      expect(Celluloid::Actor[:example_pool].size).to be size
    end
  end
end
