require "spec_helper"

describe Parallel do

  around(:each) do |example|
    system("rm -rf *.out")
    example.run
    system("rm -rf *.out")
  end

  it "can flush buffers with the help of :yield_on_done" do
    described_class.each 1..10, processes: 2, yield_on_done: true do |n|
      @file   ||= File.open("spec_#{Process.pid}.out", "w")
      @buffer ||= []
      @index  ||= 0

      if n == Parallel::Done
        @buffer.each{ |item| @file << "#{item}\n" }
        @file.close
        next
      end

      @index += 1
      @buffer << n

      if @index % 4 == 0
        @buffer.each{ |item| @file << "#{item}\n" }
        @buffer = []
      end
    end

    expect(`cat *.out | wc -l`.to_i).to eq(10)
  end

end
