require 'spec_helper'

describe Parallel::Mapper do

  it "works on arrays" do
    mapper = described_class.new([1, 2, 3]){ |n| n * 2 }
    expect(mapper.run).to eq([2, 4, 6])
  end

  it "works on ranges" do
    mapper = described_class.new(1..3){ |n| n * 2 }
    expect(mapper.run).to eq([2, 4, 6])
  end

  it "runs on multiple processes" do
    pids = described_class.new(1..10, processes: 3){ Process.pid }.run
    expect(pids.uniq.length).to eq(3)
    expect(pids).to_not include(Process.pid)
  end

  it "block can take more than one argument" do
    mapper = described_class.new(1..3){ |n, m| [n * 2, m] }
    expect(mapper.run).to eq([[2, nil], [4, nil], [6, nil]])
  end

  it "keeps things in the right order" do
    delays = [0, 0.05, 0.10]
    values = described_class.new(1..10){ |n| sleep(delays.sample); n * 2 }.run
    expect(values).to eq( (1..10).map{ |n| n * 2 } )
  end

  it "cannot partition properly" do
    mapper = described_class.new(1..10) do |n|
      @index  ||= 0
      @buffer ||= []

      @buffer << n
      @index += 1

      if @index % 4 == 0
        @buffer.tap{ @buffer = [] }
      else
        nil
      end
    end

    expect(mapper.run.flatten.compact.length).to eq(8)
  end

  it "calls the block with Done if :yield_on_done" do
    error = RuntimeError.new("foo")
    mapper = described_class.new(1..10, yield_on_done: true) do |n|
      if n == Parallel::Done
        raise error
      else
        n * 2
      end
    end
    expect{ mapper.run }.to raise_error(RuntimeError, /foo/)

    mapper = described_class.new(1..10, yield_on_done: true) do |n|
      n * 2 unless n == Parallel::Done
    end
    expect(mapper.run).to eq((1..10).map{ |n| n * 2 })
  end

end
