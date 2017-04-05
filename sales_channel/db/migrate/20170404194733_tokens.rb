class Tokens < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :myshopify_domain
      t.string :shopify_token
    end
  end
end
