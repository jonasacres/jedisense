#!/usr/bin/ruby

require 'json'
require 'net/http'

url = URI.parse('http://presence.acreswonder.com:3200/people')
req = Net::HTTP::Get.new(url.path)
res = Net::HTTP.start(url.host, url.port) {|http|
  http.request(req)
}

clients = JSON.parse(res.body)
clients.each do |client|
  next unless client.has_key?("user")
  puts "#{client['user']}"
end
