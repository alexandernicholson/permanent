require 'sinatra/base'
require 'set'
require 'net/http'
require 'uri'
require 'json'
require 'fileutils'
require 'logger'

class DisposableEmailChecker < Sinatra::Base
  configure do
    set :server, :puma
    set :logging, false
    set :static, false
    set :sessions, false
    set :protection, false
    set :x_cascade, false
    
    enable :reloader if development?
  end
  
  # Custom lightweight logger for performance
  class RequestLogger
    def initialize
      @logger = Logger.new(STDOUT)
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} #{msg}\n"
      end
    end
    
    def log_request(env, status, domain = nil)
      method = env['REQUEST_METHOD']
      path = env['PATH_INFO']
      query = env['QUERY_STRING']
      ip = env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR']
      
      domain_part = domain ? " domain=#{domain}" : ""
      @logger.info "#{method} #{path} ip=#{ip} status=#{status}#{domain_part}"
    end
  end
  
  @@logger = RequestLogger.new

  DOMAINS_FILE = File.join(__dir__, 'sources', 'disposable-email-domains', 'domains.txt')
  DOMAINS_URL = 'https://raw.githubusercontent.com/disposable/disposable-email-domains/master/domains.txt'
  UPDATE_INTERVAL = 3600
  
  @@domains = Set.new
  @@last_update = 0
  @@update_mutex = Mutex.new
  
  def self.load_domains_from_file
    if File.exist?(DOMAINS_FILE)
      domains = Set.new
      File.foreach(DOMAINS_FILE) do |line|
        domain = line.strip.downcase
        domains.add(domain) unless domain.empty?
      end
      domains
    else
      Set.new
    end
  end
  
  def self.update_domains_from_url
    begin
      uri = URI(DOMAINS_URL)
      response = Net::HTTP.get_response(uri)
      
      if response.code == '200'
        domains = Set.new
        response.body.each_line do |line|
          domain = line.strip.downcase
          domains.add(domain) unless domain.empty?
        end
        
        FileUtils.mkdir_p(File.dirname(DOMAINS_FILE))
        File.write(DOMAINS_FILE, response.body)
        
        domains
      else
        nil
      end
    rescue => e
      nil
    end
  end
  
  def self.update_domains_if_needed
    current_time = Time.now.to_i
    
    return unless current_time - @@last_update > UPDATE_INTERVAL
    
    @@update_mutex.synchronize do
      return unless current_time - @@last_update > UPDATE_INTERVAL
      
      updated_domains = update_domains_from_url
      
      if updated_domains && !updated_domains.empty?
        @@domains = updated_domains
      elsif @@domains.empty?
        @@domains = load_domains_from_file
      end
      
      @@last_update = current_time
    end
  end
  
  @@domains = load_domains_from_file
  @@last_update = Time.now.to_i
  
  Thread.new do
    loop do
      sleep(UPDATE_INTERVAL)
      update_domains_if_needed
    end
  end
  
  before do
    content_type :json
  end
  
  get '/check' do
    email = params['email']
    
    unless email
      @@logger.log_request(env, 400)
      return [400, { error: 'Email parameter required' }.to_json]
    end
    
    parts = email.split('@')
    unless parts.length == 2
      @@logger.log_request(env, 400)
      return [400, { error: 'Invalid email format' }.to_json]
    end
    
    domain = parts[1].downcase
    
    is_disposable = @@domains.include?(domain)
    
    @@logger.log_request(env, 200, domain)
    
    { disposable: is_disposable }.to_json
  end
  
  get '/health' do
    @@logger.log_request(env, 200)
    
    {
      status: 'ok',
      domains_loaded: @@domains.size,
      last_update: @@last_update
    }.to_json
  end
  
  run! if app_file == $0
end