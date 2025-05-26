require 'benchmark/ips'
require 'net/http'
require 'uri'
require 'json'
require 'concurrent'

PORT = ENV['PORT'] || 3000
BASE_URL = "http://localhost:#{PORT}"
HOST = 'localhost'

# Connection pool for reusing HTTP connections
class ConnectionPool
  def initialize(size: 10, host:, port:)
    @size = size
    @host = host
    @port = port
    @available = Queue.new
    @connections = []
    @mutex = Mutex.new
    
    # Pre-create connections
    size.times do
      conn = create_connection
      @connections << conn
      @available << conn
    end
  end
  
  def with_connection
    conn = checkout
    yield conn
  ensure
    checkin(conn) if conn
  end
  
  def close_all
    @mutex.synchronize do
      @connections.each do |conn|
        conn.finish if conn.started?
      rescue
        # Ignore errors when closing
      end
      @connections.clear
      @available.clear
    end
  end
  
  private
  
  def create_connection
    http = Net::HTTP.new(@host, @port)
    http.open_timeout = 5
    http.read_timeout = 5
    http.keep_alive_timeout = 30
    http.start
    http
  end
  
  def checkout
    # Try to get an available connection with timeout
    begin
      @available.pop(true)
    rescue ThreadError
      # Queue is empty, wait a bit
      sleep(0.01)
      retry
    end
  end
  
  def checkin(conn)
    if conn.started?
      @available << conn
    else
      # Connection is dead, create a new one
      @mutex.synchronize do
        @connections.delete(conn)
        new_conn = create_connection
        @connections << new_conn
        @available << new_conn
      end
    end
  rescue
    # If there's any error, try to create a new connection
    @mutex.synchronize do
      @connections.delete(conn)
      begin
        new_conn = create_connection
        @connections << new_conn
        @available << new_conn
      rescue
        # If we can't create a new connection, just remove the old one
      end
    end
  end
end

# Global connection pool
$connection_pool = ConnectionPool.new(size: 50, host: HOST, port: PORT)

def make_request(email)
  uri = URI("#{BASE_URL}/check?email=#{email}")
  
  $connection_pool.with_connection do |http|
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    JSON.parse(response.body) if response.code == '200'
  end
rescue => e
  puts "Error: #{e.message}"
  nil
end

def concurrent_requests(count, email)
  # Limit concurrency to avoid overwhelming the system
  max_threads = [count, 50].min
  pool = Concurrent::FixedThreadPool.new(max_threads)
  
  # Add rate limiting for large request counts
  delay = count > 1000 ? 0.001 : 0
  
  promises = count.times.map do |i|
    sleep(delay) if delay > 0 && i % 100 == 0
    
    Concurrent::Promise.execute(executor: pool) do
      make_request(email)
    end
  end
  
  promises.map(&:value!)
ensure
  pool.shutdown
  pool.wait_for_termination
end

puts "Performance Benchmark for Disposable Email Checker"
puts "=" * 50
puts "Testing against: #{BASE_URL}"
puts

puts "Checking if server is running..."
begin
  # Use connection pool for health check too
  $connection_pool.with_connection do |http|
    request = Net::HTTP::Get.new('/health')
    response = http.request(request)
    if response.code == '200'
      health = JSON.parse(response.body)
      puts "✓ Server is healthy"
      puts "  Domains loaded: #{health['domains_loaded']}"
    else
      puts "✗ Server returned status: #{response.code}"
      exit 1
    end
  end
rescue => e
  puts "✗ Server is not running: #{e.message}"
  puts "  Please start the server with: bundle exec puma -C puma.rb"
  exit 1
end

puts "\nRunning benchmarks..."
puts "-" * 50

disposable_email = "test@tempmail.com"
non_disposable_email = "test@gmail.com"

# Warm up the connection pool
puts "Warming up connection pool..."
10.times { make_request(disposable_email) }

Benchmark.ips do |x|
  x.config(time: 10, warmup: 2)
  
  x.report("Disposable email check") do
    make_request(disposable_email)
  end
  
  x.report("Non-disposable email check") do
    make_request(non_disposable_email)
  end
  
  x.compare!
end

puts "\nConcurrent request test..."
puts "-" * 50

[100, 1000, 5000].each do |count|
  print "Testing #{count} concurrent requests... "
  start_time = Time.now
  results = concurrent_requests(count, disposable_email)
  duration = Time.now - start_time
  successful = results.compact.size
  rps = successful / duration
  
  puts "✓"
  puts "  Duration: #{duration.round(2)}s"
  puts "  Successful: #{successful}/#{count}"
  puts "  RPS: #{rps.round(0)}"
  puts
  
  # Give the system a brief pause between tests
  sleep(0.5)
end

puts "\nEstimated maximum RPS based on benchmarks:"
puts "Note: Actual RPS will depend on hardware, network, and server configuration"

# Clean up
$connection_pool.close_all