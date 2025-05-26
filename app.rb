require 'set'
require 'json'
require 'logger'
require 'thread'

# Fast Rack application with async logging
class DisposableEmailCheckerFast
  DOMAINS_FILE = File.join(__dir__, 'sources', 'disposable-email-domains', 'domains.txt')
  
  # Pre-serialized JSON responses
  ERROR_EMAIL_REQUIRED = '{"error":"Email parameter required"}'.freeze
  ERROR_INVALID_FORMAT = '{"error":"Invalid email format"}'.freeze
  ERROR_NOT_FOUND = '{"error":"Not found"}'.freeze
  
  DISPOSABLE_TRUE = '{"disposable":true}'.freeze
  DISPOSABLE_FALSE = '{"disposable":false}'.freeze
  
  # Headers
  CONTENT_TYPE_JSON = { 'Content-Type' => 'application/json' }.freeze
  
  # Custom lightweight logger for performance
  class AsyncLogger
    def initialize
      @queue = Queue.new
      @queue_max = 10000
      @buffer = []
      @buffer_size = 100
      @mutex = Mutex.new
      
      # Direct IO without Logger overhead
      @output = STDOUT
      @output.sync = true
      
      start_logger_thread
    end
    
    def start_logger_thread
      # Start background logging thread with batch processing
      @thread = Thread.new do
        loop do
          begin
            # Batch process entries for efficiency
            entries = []
            
            # Collect up to buffer_size entries
            @buffer_size.times do
              entry = @queue.pop(true) rescue nil
              break unless entry
              entries << entry
            end
            
            # If no entries collected, wait for one
            if entries.empty?
              entry = @queue.pop
              entries << entry
            end
            
            # Write all entries at once
            unless entries.empty?
              timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
              entries.each do |e|
                @output.puts "#{timestamp} #{e}"
              end
            end
          rescue => e
            # Silently ignore logging errors
          end
        end
      end
      @thread.priority = -2 # Even lower priority
    end
    
    def log_request(method, path, ip, status, domain = nil)
      # Ultra-fast non-blocking add
      return if @queue.size >= @queue_max
      
      # Pre-formatted string without allocations
      entry = domain ? "#{method} #{path} ip=#{ip} status=#{status} domain=#{domain}" : 
                      "#{method} #{path} ip=#{ip} status=#{status}"
      
      @queue << entry rescue nil
    end
  end
  
  def initialize
    @domains = load_domains
    @last_update = Time.now.to_i
    @domains_size = @domains.size
    
    # Logger will be initialized on first request in each worker
    @logger = nil
    
    # Pre-build health response
    @health_response = "{\"status\":\"ok\",\"domains_loaded\":#{@domains_size},\"last_update\":#{@last_update}}"
  end
  
  def load_domains
    domains = Set.new
    if File.exist?(DOMAINS_FILE)
      File.foreach(DOMAINS_FILE) do |line|
        domain = line.strip.downcase
        domains.add(domain) unless domain.empty?
      end
    end
    domains
  end
  
  def call(env)
    # Initialize logger on first request if needed (once per worker)
    if @logger.nil? && ENV['DISABLE_LOGGING'] != 'true'
      @logger = AsyncLogger.new
    end
    
    path = env['PATH_INFO']
    
    case path
    when '/check'
      handle_check(env)
    when '/health'
      if @logger
        method = env['REQUEST_METHOD']
        ip = env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR']
        @logger.log_request(method, path, ip, 200)
      end
      [200, CONTENT_TYPE_JSON, [@health_response]]
    else
      [404, CONTENT_TYPE_JSON, [ERROR_NOT_FOUND]]
    end
  end
  
  private
  
  def handle_check(env)
    query_string = env['QUERY_STRING']
    
    # Fast path for successful requests (most common case)
    if query_string && !query_string.empty?
      # Simple parameter extraction
      params = parse_query(query_string)
      email = params['email']
      
      if email
        # Find @ position
        at_pos = email.index('@')
        if at_pos && at_pos > 0 && at_pos < email.length - 1
          # Extract domain
          domain = email[(at_pos + 1)..-1].downcase
          
          # Check if disposable
          response_body = @domains.include?(domain) ? DISPOSABLE_TRUE : DISPOSABLE_FALSE
          
          # Log successful request
          @logger.log_request('GET', '/check', env['REMOTE_ADDR'], 200, domain) if @logger
          
          return [200, CONTENT_TYPE_JSON, [response_body]]
        end
      end
    end
    
    # Slow path for error cases
    if @logger
      method = env['REQUEST_METHOD']
      ip = env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR']
      
      if query_string.nil? || query_string.empty?
        @logger.log_request(method, '/check', ip, 400)
        return [400, CONTENT_TYPE_JSON, [ERROR_EMAIL_REQUIRED]]
      elsif !params || !params['email']
        @logger.log_request(method, '/check', ip, 400)
        return [400, CONTENT_TYPE_JSON, [ERROR_EMAIL_REQUIRED]]
      else
        @logger.log_request(method, '/check', ip, 400)
        return [400, CONTENT_TYPE_JSON, [ERROR_INVALID_FORMAT]]
      end
    else
      if query_string.nil? || query_string.empty? || !params || !params['email']
        return [400, CONTENT_TYPE_JSON, [ERROR_EMAIL_REQUIRED]]
      else
        return [400, CONTENT_TYPE_JSON, [ERROR_INVALID_FORMAT]]
      end
    end
  end
  
  def parse_query(query_string)
    params = {}
    query_string.split('&').each do |pair|
      key, value = pair.split('=', 2)
      params[key] = value if key && value
    end
    params
  end
end
