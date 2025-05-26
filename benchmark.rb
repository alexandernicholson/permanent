#!/usr/bin/env ruby

require 'benchmark/ips'
require 'net/http'
require 'uri'

# Configuration
PORT = ENV['PORT'] || 8080
ENDPOINT = "http://localhost:#{PORT}"

def benchmark_endpoint(path, params = nil)
  uri = URI("#{ENDPOINT}#{path}")
  uri.query = URI.encode_www_form(params) if params
  
  Benchmark.ips do |x|
    x.config(time: 10, warmup: 2)
    
    x.report("#{path} request") do
      Net::HTTP.get_response(uri)
    end
  end
end

puts "Benchmarking server at #{ENDPOINT}"
puts "=" * 50

puts "\nHealth endpoint:"
benchmark_endpoint('/health')

puts "\nCheck endpoint (disposable domain):"
benchmark_endpoint('/check', email: 'test@mailinator.com')

puts "\nCheck endpoint (non-disposable domain):"
benchmark_endpoint('/check', email: 'test@gmail.com')