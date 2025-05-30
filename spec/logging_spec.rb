require 'spec_helper'
require 'stringio'

RSpec.describe 'Request Logging' do
  let(:log_output) { StringIO.new }
  
  before do
    # Redirect logger output to our StringIO for testing
    allow(Logger).to receive(:new).with(STDOUT).and_return(Logger.new(log_output))
    # Clear the queue before each test
    DisposableEmailCheckerFast::LOG_QUEUE.clear
  end
  
  after do
    # Process any pending log entries
    sleep(0.1) # Give the logger thread time to process
  end
  
  describe 'GET /check' do
    context 'successful requests' do
      it 'logs request with domain when email is valid' do
        get '/check?email=user@example.com'
        
        # Wait for async logging
        sleep(0.1)
        
        log_output.rewind
        log_content = log_output.read
        
        expect(log_content).to match(/GET \/check/)
        expect(log_content).to match(/status=200/)
        expect(log_content).to match(/domain=example\.com/)
        expect(log_content).to match(/ip=127\.0\.0\.1/)
      end
      
      it 'logs only the domain, not the full email' do
        get '/check?email=sensitive.user@tempmail.com'
        
        # Wait for async logging
        sleep(0.1)
        
        log_output.rewind
        log_content = log_output.read
        
        expect(log_content).to include('domain=tempmail.com')
        expect(log_content).not_to include('sensitive.user')
      end
      
      it 'logs domain in lowercase' do
        get '/check?email=USER@EXAMPLE.COM'
        
        # Wait for async logging
        sleep(0.1)
        
        log_output.rewind
        log_content = log_output.read
        
        expect(log_content).to include('domain=example.com')
      end
    end
    
    context 'failed requests' do
      it 'logs 400 status when email parameter is missing' do
        get '/check'
        
        # Wait for async logging
        sleep(0.1)
        
        log_output.rewind
        log_content = log_output.read
        
        expect(log_content).to match(/GET \/check/)
        expect(log_content).to match(/status=400/)
        expect(log_content).not_to match(/domain=/)
      end
      
      it 'logs 400 status when email format is invalid' do
        get '/check?email=notanemail'
        
        # Wait for async logging
        sleep(0.1)
        
        log_output.rewind
        log_content = log_output.read
        
        expect(log_content).to match(/GET \/check/)
        expect(log_content).to match(/status=400/)
        expect(log_content).not_to match(/domain=/)
      end
    end
  end
  
  describe 'GET /health' do
    it 'logs health check requests' do
      get '/health'
      
      # Wait for async logging
      sleep(0.1)
      
      log_output.rewind
      log_content = log_output.read
      
      expect(log_content).to match(/GET \/health/)
      expect(log_content).to match(/status=200/)
      expect(log_content).not_to match(/domain=/)
    end
  end
  
  describe 'log format' do
    it 'includes timestamp in the correct format' do
      get '/health'
      
      # Wait for async logging
      sleep(0.1)
      
      log_output.rewind
      log_content = log_output.read
      
      # Check for timestamp format: YYYY-MM-DD HH:MM:SS
      expect(log_content).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/)
    end
    
    it 'logs X-Forwarded-For header when present' do
      header 'X-Forwarded-For', '192.168.1.100'
      get '/health'
      
      # Wait for async logging
      sleep(0.1)
      
      log_output.rewind
      log_content = log_output.read
      
      expect(log_content).to include('ip=192.168.1.100')
    end
  end
end