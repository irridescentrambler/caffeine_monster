# frozen_string_literal: true

require 'net/http'
require 'uri'

URL = ENV.fetch('URL', 'http://0.0.0.0:3000/users')
THREADS = Integer(ENV.fetch('THREADS', '50'))
REQUESTS_PER_THREAD = Integer(ENV.fetch('REQUESTS_PER_THREAD', '50'))
OPEN_TIMEOUT = Float(ENV.fetch('OPEN_TIMEOUT', '2.0'))
READ_TIMEOUT = Float(ENV.fetch('READ_TIMEOUT', '5.0'))
BEARER_TOKEN = 'ABC'

uri = URI(URL)

mutex = Mutex.new
latencies_ms = []
status_counts = Hash.new(0)
error_counts = Hash.new(0)

start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

threads = Array.new(THREADS) do
  Thread.new do
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', open_timeout: OPEN_TIMEOUT,
                                            read_timeout: READ_TIMEOUT) do |http|
      REQUESTS_PER_THREAD.times do
        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = "Bearer #{BEARER_TOKEN}" if BEARER_TOKEN.present?
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        begin
          response = http.request(request)
          t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          mutex.synchronize do
            latencies_ms << ((t1 - t0) * 1000.0)
            status_counts[response.code] += 1
          end
        rescue Net::OpenTimeout, Net::ReadTimeout => e
          t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          mutex.synchronize do
            latencies_ms << ((t1 - t0) * 1000.0)
            error_counts[e.class.name] += 1
          end
        rescue StandardError => e
          mutex.synchronize do
            error_counts[e.class.name] += 1
          end
        end
      end
    end
  rescue StandardError => e
    mutex.synchronize do
      error_counts[e.class.name] += REQUESTS_PER_THREAD
    end
  end
end

threads.each(&:join)

elapsed_s = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
total_requests = THREADS * REQUESTS_PER_THREAD
completed = status_counts.values.sum
errors = error_counts.values.sum

sorted = latencies_ms.sort
def percentile(sorted, percent)
  return nil if sorted.empty?

  rank = (percent * (sorted.length - 1)).round
  sorted[[rank, 0].max]
end

avg = sorted.empty? ? nil : (sorted.sum / sorted.length)

# rubocop:disable Style/FormatStringToken
puts "URL=#{URL}"
puts "threads=#{THREADS} requests_per_thread=#{REQUESTS_PER_THREAD} total=#{total_requests}"
puts format('elapsed=%.2fs rps=%.1f', elapsed_s, total_requests / elapsed_s)
puts "completed=#{completed} errors=#{errors}"
puts "status_counts=#{status_counts.sort.to_h}"
puts "error_counts=#{error_counts.sort.to_h}" unless error_counts.empty?

if avg
  puts format('latency_ms avg=%.1f p50=%.1f p95=%.1f p99=%.1f max=%.1f',
              avg,
              percentile(sorted, 0.50),
              percentile(sorted, 0.95),
              percentile(sorted, 0.99),
              sorted.last)
end
# rubocop:enable Style/FormatStringToken
