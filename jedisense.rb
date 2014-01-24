#!/usr/bin/ruby

require 'date'
require 'mongo'
require 'rubygems'
require 'sinatra'
require 'json'
require 'net/http'
require 'rest-client'
require 'webrick'
require 'webrick/https'
require 'openssl'

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
  return sighting != nil
end

def sendEmail(subject, body, recipients)
  url = "https://api:#{$MAILGUN_KEY}@api.mailgun.net/v2/#{$MAILGUN_DOMAIN}/messages"
  RestClient.post url,
    :from => $MAILGUN_FROM,
    :to => recipients.join(", "),
    :subject => subject,
    :html => body
end

class JediSense < Sinatra::Base
  get '/people' do
    if request.env["HTTP_AUTHORIZATION"]
      comps = request.env["HTTP_AUTHORIZATION"].split(' ')
      if(comps.length !=2 || comps[0] != "Bearer" || comps[1] != ENV["ACCESS_TOKEN"]) then
        status 403
        body "Invalid token\n"
        return
      end
    else
      puts "No authentication\n"
      status 401
      body "Authentication required\n"
      return
    end
    
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
    $VALIDATOR
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

      $db["clients"].insert(c);
      logger.info "client #{c['client_mac']} seen on ap #{c['ap_mac']} with rssi #{c['rssi']} at #{c['last_seen']}"
    end
    ""
  end
end

app = Rack::Builder.new do
  map '/' do
    run JediSense
  end
end

cert = OpenSSL::X509::Certificate.new File.read '_ssl/certificate.crt'
pkey = OpenSSL::PKey::RSA.new File.read '_ssl/private.key'
webrickOpts = {
  :Port => ENV["HTTPS_PORT"],
  :SSLEnable => true,
  :SSLCertificate => cert,
  :SSLPrivateKey => pkey,
  :SSLVerifyClient => OpenSSL::SSL::VERIFY_NONE
}

Signal.trap('INT') {
  Rack::Handler::WEBrick.shutdown
}
Rack::Handler::WEBrick.run app, webrickOpts
