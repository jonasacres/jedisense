#!/usr/bin/ruby

require 'mongo'
require 'rubygems'
require 'sinatra'
require 'json'

include Mongo

SECRET = ENV['PRESENCE_SECRET']
VALIDATOR = ENV['PRESENCE_VALIDATOR']
MONGO_HOST = ENV['MONGO_HOST']
MONGO_PORT = ENV['MONGO_PORT']
MONGO_DBNAME = ENV['MONGO_DBNAME']

db = MongoClient.new(MONGO_HOST, MONGO_PORT).db(MONGO_DBNAME)

get '/events' do
  VALIDATOR
end

post '/events' do
  map = JSON.parse(params[:data])
  if map['secret'] != SECRET
    logger.warn "got post with bad secret: #{map['secret']}"
    return
  end
  
  map['probing'].each do |c|
    cleanedClient = c
    components = c['client_mac'].split(" ")
    cleanedClient['client_mac'] = components[0]
    cleanedClient['timestamp'] = components[1]
    db["clients"].insert(cleanedClient);
    logger.info "client #{cleanedClient['client_mac']} seen on ap #{c['ap_mac']} with rssi #{c['rssi']} at #{c['last_seen']}"
  end
  ""
end
