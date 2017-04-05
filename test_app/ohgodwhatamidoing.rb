require 'shopify_api'
require 'sinatra'
require 'httparty'
require 'dotenv'
require 'pry'

class OHGODWHATAMIDOING < Sinatra::Base

  enable :sessions
  set :protection, :except => :frame_options

  def initialize
    Dotenv.load
    @key = ENV['API_KEY']
    @secret = ENV['API_SECRET']
    @app_url = "twheels.ngrok.io"
    @tokens = {}
    super
  end

  post "/poop/webhook" do
    request.body.rewind
    binding.pry
    data = request.body.read

    verified = verify_webhook(data, env["HTTP_X_SHOPIFY_HMAC_SHA256"])

    puts "Webhook verified: #{verified}"

    if not verified
     return [401, "DAMN BRUH THAT WASN'T GOOD"]
    else
     return [200, "FUCK YEAH SON"]
    end

    session = ShopifyAPI::Session.new("#{@@shop}", @tokens[@@shop])
    ShopifyAPI::Base.activate_session(session)
    request.body.rewind
    parsed_hook = JSON.parse request.body.read

    order = ShopifyAPI::Order.find(parsed_hook['id'])

    fulfillment = ShopifyAPI::Fulfillment.new(order_id: order.id, line_items: order.line_items, notify_customer: "true")

  end

  get "/proxy/" do
    content_type "application/liquid"
    erb :index
  end

  post "/home" do
    session = ShopifyAPI::Session.new(@@shop,@tokens[@@shop])
    ShopifyAPI::Base.activate_session(session)
    @order = ShopifyAPI::Order.find(request.params['order_id'])

    erb :fulfillment, :locals => {'order' => @order}
  end

  get "/home" do
    erb :index
  end

  get "/install" do
    @@shop = params['shop']
    scopes = "read_orders,write_orders,read_fulfillments,write_fulfillments,read_products,write_products"
    redirect_uri = "https://twheels.ngrok.io/poop/auth"

    install = "https://#{@@shop}/admin/oauth/authorize?client_id=#{@key}&scope=#{scopes}&redirect_uri=#{redirect_uri}"

    redirect install
  end

 get "/poop/auth" do
   query = params.reject{|k,_| k == 'hmac'}
   message = Rack::Utils.build_query(query)

   hmac =  OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), @secret, message)

   if hmac == params['hmac']
     get_access_token(params)
   else
     return [401, "HMAC validation failed"]
   end
 end

 post '/proxy/' do
   puts "Hello, World!"
   return [200]
 end

 helpers do
   def get_access_token(params)

     code = params['code']
     url = "https://#{@@shop}/admin/oauth/access_token"

     response = HTTParty.post(url, body: { client_id: @key, client_secret: @secret, code: code })
       if (response.code == 200)
         @tokens[@@shop] = response['access_token']
       else
         return [500, "GTFO"]
       end

       session = ShopifyAPI::Session.new("#{@@shop}", @tokens[@@shop])
       ShopifyAPI::Base.activate_session(session)

       create_webhook

       redirect "/home"
    end

    def create_webhook
      webhook = ShopifyAPI::Webhook.create(address: "http://twheels.ngrok.io/poop/webhook", topic: "orders/paid", format: "json")
    end

    def verify_webhook(data, hmac)
      digest  = OpenSSL::Digest::Digest.new('sha256')
      calculated_hmac = Base64.encode64(OpenSSL::HMAC.digest(digest, @secret, data)).strip
      calculated_hmac == hmac
    end
   end
  end

OHGODWHATAMIDOING.run! if __FILE__ == $0
