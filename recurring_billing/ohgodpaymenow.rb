require 'shopify_api'
require 'sinatra'
require 'httparty'
require 'dotenv'
require 'pry'

class OHGODWHATAMIDOING < Sinatra::Base

  enable :sessions

  def initialize
    Dotenv.load
    @key = ENV['API_KEY']
    @secret = ENV['API_SECRET']
    @app_url = "twheels2.ngrok.io"
    @tokens = {}
    super
  end

  post "/poop/webhook" do
    request.body.rewind
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

  post "/home" do
    session = ShopifyAPI::Session.new(@@shop,@tokens[@@shop])
    ShopifyAPI::Base.activate_session(session)
    @order = ShopifyAPI::Order.find(request.params['order_id'])

    erb :fulfillment, :locals => {'order' => @order}
  end


  get "/home" do
    binding.pry
    erb :index
  end

  get "/install" do

    @@shop = params['shop']
    scopes = "read_orders,write_orders,read_fulfillments,write_fulfillments"
    redirect_uri = "http://#{@app_url}/poop/auth"

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
       application_charge
    end

    def create_webhook
      webhook = ShopifyAPI::Webhook.create(address: "http://#{@app_url}/poop/webhook", topic: "orders/paid", format: "json")
    end

    def verify_webhook(data, hmac)
      digest  = OpenSSL::Digest::Digest.new('sha256')
      calculated_hmac = Base64.encode64(OpenSSL::HMAC.digest(digest, @secret, data)).strip
      calculated_hmac == hmac
    end
   end
  end

  def create_recurring_application_charge
      unless ShopifyAPI::RecurringApplicationCharge.current
      recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.new(
        name: "Gift Basket Plan",
        price: 9.99,
        return_url: "https:\/\/#{@app_url}\/activatecharge",
        test: true,
        trial_days: 7,
        capped_amount: 100,
        terms: "$0.99 for every order created")

      if recurring_application_charge.save
        @tokens[:confirmation_url] = recurring_application_charge.confirmation_url
        redirect recurring_application_charge.confirmation_url
      end
    end

    def application_charge
      application_charge = ShopifyAPI::ApplicationCharge.new(
        name: "One-time charge",
        price: 10.00,
        return_url: "https:\/\/#{@app_url}\/activatecharge")

    
    end
  end

OHGODWHATAMIDOING.run! if __FILE__ == $0
