#!/usr/bin/ruby

require 'date'
require 'mongo'
require 'rubygems'
require 'sinatra'
require 'json'
require 'net/http'
require 'rest-client'

include Mongo

$SECRET = ENV['PRESENCE_SECRET']
$VALIDATOR = ENV['PRESENCE_VALIDATOR']
$MONGO_HOST = ENV['MONGO_HOST']
$MONGO_PORT = ENV['MONGO_PORT']
$MONGO_DBNAME = ENV['MONGO_DBNAME']
$MAILGUN_KEY = ENV['MAILGUN_API_KEY']
$MAILGUN_DOMAIN = ENV['MAILGUN_DOMAIN']
$MAILGUN_FROM = ENV['MAILGUN_FROM']

$db = MongoClient.new($MONGO_HOST, $MONGO_PORT).db($MONGO_DBNAME)

def epochForTimeSeen(ts)
  # eg "Mon Jan 20 20:10:17.418 UTC 2014", [ Weekday, Month, Day, Timecode, UTC, Year ]
  return Time.parse(ts).to_i
end

def recentlySeen?(mac)
  sighting = $db["clients"].find_one( { "$query" => { 'client_mac' => mac }, "$orderby" => { 'last_seen_epoch' => -1 }  } )
  return false unless sighting
  
  timeAgo = Time.new().to_i - sighting["last_seen_epoch"].to_i
  return timeAgo <= 60*60*8
end

def sendEmail(subject, body, recipients)
  url = "https://api:#{$MAILGUN_KEY}@api.mailgun.net/v2/#{$MAILGUN_DOMAIN}/messages"
  RestClient.post url,
    :from => $MAILGUN_FROM,
    :to => recipients.join(", "),
    :subject => subject,
    :html => body
end

get '/people' do
  content_type :json
  
  devices = $db["devices"].find().to_a
  usersByMac = {}
  devices.each do |device|
    usersByMac[device["mac"]] = device["name"]
  end
  
  minTimestamp = Time.new().to_i - 60*10
  clients = $db["clients"].find({
      "$query" => { "last_seen_epoch" => { "$gt" => minTimestamp } },
    "$orderby" => { "last_seen_epoch" => -1 }
    })
  
  seenRecords = {}
  clients.each do |client|
    next if seenRecords.has_key?(client["client_mac"])
    client["user"] = usersByMac[client["client_mac"]]
    recordKeys = ["client_mac", "ap_mac", "last_seen_epoch", "rssi", "user", "site"]
    record = {}
    recordKeys.each do |key|
      record[key] = client[key] if client[key] != nil
    end
    
    seenRecords[client["client_mac"]] = record
  end
  
  seenRecords.values.to_json
end

get '/events/:site' do
<<<<<<< HEAD
  $VALIDATOR
=======
  VALIDATOR
>>>>>>> 5815f5d2286beb3c41c60dfac072d2a14653ddf3
end

post '/events/:site' do
  map = JSON.parse(params[:data])
  if map['secret'] != $SECRET
    logger.warn "got post with bad secret: #{map['secret']}"
    return
  end
  
  map['probing'].each do |c|
    c["last_seen_epoch"] = epochForTimeSeen(c["last_seen"])
    c["site"] = params["site"]
    
    if c["client_mac"] == "00:88:65:d3:b3:39" and not recentlySeen?(c["client_mac"]) then
      sendEmail("Mark Dailey has arrived at the office", "Lo, on this fine morn, our Captain arrives to Preside Over our Labors with His Noble Guidance!", ["developers@acres4.com","roy.corby@acres4.com"])
    end
    
    $db["clients"].insert(c);
    logger.info "client #{c['client_mac']} seen on ap #{c['ap_mac']} with rssi #{c['rssi']} at #{c['last_seen']}"
  end
  ""
end
