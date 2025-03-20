require_relative 'money_transfer_script'
require 'benchmark'

threads = []
200.times do
  threads << Thread.new do
    add_money(3, 10)
  end
end

measured_benchmark = Benchmark.measure do
  threads.each(&:join)
end

puts measured_benchmark
