RSpec.describe Celluloid::Supervision::Container::Pool, actor_system: :global do
  class ExampleError < StandardError; end

  class MyWorker
    include Celluloid

    def process(queue = nil)
      if queue
        queue << :done
      else
        :done
      end
    end

    def sleepy_work
      t = Time.now.to_f
      sleep 0.25
      t
    end

    def sleepier_work
      sleep 1.0
      :worky
    end

    def crash
      fail ExampleError, "zomgcrash"
    end

    protected

    def a_protected_method
    end

    private

    def a_private_method
    end
  end

  def test_concurrency_of(pool)
    baseline = Time.now.to_f
    values = 10.times.map { pool.future.sleepy_work }.map(&:value)
    values.select { |t| t - baseline < 0.1 }.length
  end

  context "when auditing actors directly, whether they are idle or not" do
    let(:size) { SupervisionContainerHelper::SIZE }

    before(:each) {
      subject { MyPoolActor.pool }
    }

    it "has idle and busy arrays totalling the same as one actor set" do
      expect(subject.actors.length).to eq(subject.busy_size + subject.idle_size)
    end

    it "can be determined whether an actor is idle or busy" do
      busy = 0
      worky = subject.future.sleepier_work
      subject.actors.each { |actor| busy += 1 if subject.__busy?(actor) }
      expect(worky.value).to eq(:worky)
      expect(busy).to eq(1)
    end

    it "can have the actor state revealed by keyword" do
      worky = subject.future.sleepier_work
      states = subject.actors.map { |actor| subject.__state(actor) }
      expect(worky.value).to eq(:worky)
      expect(states.include?(:busy)).to be_truthy
    end
  end

  subject { MyWorker.pool }

  let(:crashes) { [] }

  before { allow(Celluloid::Internals::Logger).to receive(:crash) { |*args| crashes << args } }
  after { fail "Unexpected crashes: #{crashes.inspect}" unless crashes.empty? }

  it "processes work units synchronously" do
    expect(subject.process).to be :done
  end

  it "processes work units asynchronously" do
    queue = Queue.new
    subject.async.process(queue)
    expect(queue.pop).to be :done
  end

  it "handles crashes" do
    allow(Celluloid::Internals::Logger).to receive(:crash)
    expect { subject.crash }.to raise_error(ExampleError)
    expect(subject.process).to be :done
  end

  it "uses a fixed-sized number of threads" do
    subject # eagerly evaluate the pool to spawn it

    actors = Celluloid::Actor.all
    100.times.map { subject.future(:process) }.map(&:value)

    new_actors = Celluloid::Actor.all - actors
    expect(new_actors).to eq []
  end

  it "terminates" do
    expect { subject.terminate }.to_not raise_exception
  end

  it "handles many requests" do
    futures = 10.times.map do
      subject.future.process
    end
    futures.map(&:value)
  end

  context "allows single worker pools" do
    let(:initial_size) { 1 }

    subject { MyWorker.pool size: initial_size }

    it "properly" do
      expect(test_concurrency_of(subject)).to eq(initial_size)
    end

    context "and resizes properly" do
      let(:initial_size) { 1 } # anything other than 2 or 4 too big on Travis

      subject { MyWorker.pool size: initial_size }

      it "should adjust the pool size up" do
        expect(test_concurrency_of(subject)).to eq(initial_size)

        subject.size = 6
        expect(subject.size).to eq(6)

        expect(test_concurrency_of(subject)).to eq(6)
      end

      it "should adjust the pool size down" do
        expect(test_concurrency_of(subject)).to eq(initial_size)

        subject.size = 2
        expect(subject.size).to eq(2)
        expect(test_concurrency_of(subject)).to eq(2)
      end
    end
  end

  context "#size=" do
    let(:initial_size) { 3 } # anything other than 2 or 4 too big on Travis

    subject { MyWorker.pool size: initial_size }

    it "should adjust the pool size up" do
      expect(test_concurrency_of(subject)).to eq(initial_size)

      subject.size = 6
      expect(subject.size).to eq(6)

      expect(test_concurrency_of(subject)).to eq(6)
    end

    it "should adjust the pool size down" do
      expect(test_concurrency_of(subject)).to eq(initial_size)

      subject.size = 2
      expect(subject.size).to eq(2)
      expect(test_concurrency_of(subject)).to eq(2)
    end
  end

  context "when called synchronously" do
    subject { MyWorker.pool }

    it { is_expected.to respond_to(:process) }
    it { is_expected.to respond_to(:inspect) }
    it { is_expected.not_to respond_to(:foo) }

    it { is_expected.to respond_to(:a_protected_method) }
    it { is_expected.not_to respond_to(:a_private_method) }

    context "when include_private is true" do
      it "should respond_to :a_private_method" do
        expect(subject.respond_to?(:a_private_method, true)).to eq(true)
      end
    end
  end

  context "when called asynchronously" do
    subject { MyWorker.pool.async }

    context "with incorrect invocation" do
      let(:logger) { double(:logger) }

      before do
        stub_const("Celluloid::Internals::Logger", logger)
        allow(logger).to receive(:crash)
        allow(logger).to receive(:warn)
        allow(logger).to receive(:with_backtrace) do |*args, &block|
          block.call logger
        end
      end

      it "logs ArgumentError exception" do
        expect(logger).to receive(:crash).with(
          anything,
          instance_of(ArgumentError))

        subject.process(:something, :one_argument_too_many)
        sleep 0.001 # Let Celluloid do it's async magic
        sleep 0.1 if RUBY_PLATFORM == "java"
      end
    end

    context "when unintialized" do
      it "should provide reasonable dump" do
        expect(subject.inspect).to eq("#<Celluloid::Proxy::Async(Celluloid::Supervision::Container::Pool)>")
      end
    end
  end
end
