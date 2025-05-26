require 'spec_helper'
require 'fileutils'

RSpec.describe DisposableEmailChecker do
  before(:all) do
    FileUtils.mkdir_p(File.dirname(DisposableEmailChecker::DOMAINS_FILE))
    File.write(DisposableEmailChecker::DOMAINS_FILE, "tempmail.com\n10minutemail.com\nguerrilla.com")
    DisposableEmailChecker.class_variable_set(:@@domains, DisposableEmailChecker.load_domains_from_file)
  end

  describe 'GET /check' do
    context 'with valid email' do
      it 'returns true for disposable email' do
        get '/check?email=user@tempmail.com'
        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/json')
        response_body = JSON.parse(last_response.body)
        expect(response_body['disposable']).to be true
      end

      it 'returns false for non-disposable email' do
        get '/check?email=user@gmail.com'
        expect(last_response).to be_ok
        response_body = JSON.parse(last_response.body)
        expect(response_body['disposable']).to be false
      end

      it 'is case insensitive' do
        get '/check?email=USER@TEMPMAIL.COM'
        expect(last_response).to be_ok
        response_body = JSON.parse(last_response.body)
        expect(response_body['disposable']).to be true
      end
    end

    context 'with invalid input' do
      it 'returns 400 when email parameter is missing' do
        get '/check'
        expect(last_response.status).to eq(400)
        response_body = JSON.parse(last_response.body)
        expect(response_body['error']).to eq('Email parameter required')
      end

      it 'returns 400 for invalid email format' do
        get '/check?email=notanemail'
        expect(last_response.status).to eq(400)
        response_body = JSON.parse(last_response.body)
        expect(response_body['error']).to eq('Invalid email format')
      end
    end
  end

  describe 'GET /health' do
    it 'returns health status' do
      get '/health'
      expect(last_response).to be_ok
      response_body = JSON.parse(last_response.body)
      expect(response_body['status']).to eq('ok')
      expect(response_body['domains_loaded']).to be > 0
      expect(response_body['last_update']).to be_a(Integer)
    end
  end

  describe '.load_domains_from_file' do
    it 'loads domains from file' do
      domains = DisposableEmailChecker.load_domains_from_file
      expect(domains).to be_a(Set)
      expect(domains).to include('tempmail.com', '10minutemail.com', 'guerrilla.com')
    end

    it 'returns empty set if file does not exist' do
      allow(File).to receive(:exist?).and_return(false)
      domains = DisposableEmailChecker.load_domains_from_file
      expect(domains).to be_empty
    end
  end

  describe '.update_domains_from_url' do
    context 'when successful' do
      it 'fetches and saves domains' do
        stub_request = double('response', code: '200', body: "newdomain.com\nanotherdomain.com")
        allow(Net::HTTP).to receive(:get_response).and_return(stub_request)
        
        domains = DisposableEmailChecker.update_domains_from_url
        expect(domains).to include('newdomain.com', 'anotherdomain.com')
      end
    end

    context 'when unsuccessful' do
      it 'returns nil on HTTP error' do
        stub_request = double('response', code: '404')
        allow(Net::HTTP).to receive(:get_response).and_return(stub_request)
        
        expect(DisposableEmailChecker.update_domains_from_url).to be_nil
      end

      it 'returns nil on network error' do
        allow(Net::HTTP).to receive(:get_response).and_raise(StandardError.new('Network error'))
        
        expect(DisposableEmailChecker.update_domains_from_url).to be_nil
      end
    end
  end
end