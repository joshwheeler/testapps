require 'shopify_api'
require 'sinatra'
require 'httparty'
require 'dotenv'
require 'pry'
require 'twilio-ruby'
require 'sinatra/activerecord'
require 'rake'

class OHGODWHATAMIDOING < Sinatra::Base

  set :database, {adapter: "sqlite3", database: "db/dev.sqlite3"}
  set :protection, :except => :frame_options

  register Sinatra::ActiveRecordExtension

  class Tokens < ActiveRecord::Base
  end


  def initialize
    Dotenv.load
    $key = ENV['API_KEY']
    @secret = ENV['API_SECRET']
    @app_url = "twheels4.ngrok.io"
    @tokens = {}
    @twiliosid = ENV['TAPI_SID']
    @twiliotoken = ENV['TAPI_TOKEN']
    super
  end

  get "/home" do
    erb :index
  end

  post "/sms" do
    message = params
    sender = message['From']

    # if message['Body'] == "List"
    #   session = ShopifyAPI::Session.new("#{$shop}", @tokens[$shop])
    #   ShopifyAPI::Base.activate_session(session)
    #   @listings = ShopifyAPI::ProductListing.all(params: { application_id: 1585627})
    #
    #   @listings.each do |pl|
    #     puts "pl.product_id" + "pl.title"
    #   end
    # end

    @client = Twilio::REST::Client.new @twiliosid, @twiliotoken
    @client.account.messages.create({:from => '+16139005729', :to => sender, :body => 'Here\'s your products!'})
    binding.pry




   end

  get "/listings" do
    session = ShopifyAPI::Session.new("#{$shop}", @tokens[$shop])
    ShopifyAPI::Base.activate_session(session)
    @listings = ShopifyAPI::ProductListing.all(params: { application_id: 1585627})

    erb :listings
  end

  get "/install" do
    $shop = params['shop']
    scopes = "read_product_listings,write_checkouts"

    install = "https://#{$shop}/admin/oauth/authorize?client_id=#{$key}&scope=#{scopes}&redirect_uri=https://#{@app_url}/auth"

    redirect install
  end

 get "/auth" do
   query = params.reject{|k,_| k == 'hmac'}
   message = Rack::Utils.build_query(query)

   hmac =  OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), @secret, message)

   if hmac == params['hmac']
     get_access_token(params)
     redirect "/home"
   else
     return [401, "HMAC validation failed"]
   end
 end


 helpers do

   def get_access_token(params)
     code = params['code']
     url = "https://#{$shop}/admin/oauth/access_token"

     response = HTTParty.post(url, body: { client_id: $key, client_secret: @secret, code: code })
       if (response.code == 200)
         binding.pry
       else
         return [500, "GTFO"]
       end

       session = ShopifyAPI::Session.new("#{$shop}", @tokens[$shop])
       ShopifyAPI::Base.activate_session(session)
    end

    def verify_webhook(data, hmac)
      digest  = OpenSSL::Digest::Digest.new('sha256')
      calculated_hmac = Base64.encode64(OpenSSL::HMAC.digest(digest, @secret, data)).strip
      calculated_hmac == hmac
    end
   end
  end


OHGODWHATAMIDOING.run! if __FILE__ == $0
