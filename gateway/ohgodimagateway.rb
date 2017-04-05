require 'shopify_api'
require 'sinatra'
require 'httparty'
require 'dotenv'
require 'pry'

  class OHGODIMAGATEWAY < Sinatra::Base

    def initialize
      @key = "shopify"
      super
    end

    post "/payment" do
      
      @customer = request.params
      signature = @customer['x_signature']
      message = strip_string.sort.join

      @confirmed_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), @key, message)

      unless signature == @confirmed_signature
        return[401, "AWW SHIT"]
      end

      hash = {
          x_account_id: @customer['x_account_id'],
          x_amount: @customer['x_amount'],
          x_currency: @customer['x_currency'],
          x_gateway_reference: SecureRandom.hex,
          x_reference: @customer['x_reference'],
          x_result: "completed",
          x_test: "false",
          x_timestamp: time,
        }

       hash[:x_signature] = sign(hash)

       post_url = @customer['x_url_callback']
       cancel_url = @customer['x_url_cancel']
       complete_url = @customer['x_url_complete'] + "?" + hash.to_query

       response = HTTParty.post(post_url, body: hash)

      if (response.code == 200)
        redirect complete_url
      else
        redirect cancel_url
      end
    end

  helpers do

      def sign(hash=hash, key=@key)
        Digest::HMAC.hexdigest(hash.sort.join, key, Digest::SHA256)
      end

      def strip_string
        clean_params = @customer.reject {|k, v| k.start_with? 'x_signature'}
        clean_params.select {|k, v| k.start_with? 'x_'}
      end

      def time
        time = Time.now.utc.iso8601
      end
    end
  end


OHGODIMAGATEWAY.run! if __FILE__ == $0
