#!/usr/bin/ruby

require 'json'
require 'net/http'

url = URI.parse('http://presence.acreswonder.com:3200/people')
req = Net::HTTP::Get.new(url.path)
res = Net::HTTP.start(url.host, url.port) {|http|
  http.request(req)
}

clients = JSON.parse(res.body)
clientsByOffice = {}

countByOffice = {}
clients.each do |client|
  next unless client.has_key?("user")
  site = client["site"] || "Unknown"
  
  countByOffice[site] = 0 unless countByOffice.has_key?(site)
  clientsByOffice[site] = [] unless clientsByOffice.has_key?(site)
  countByOffice[site] += 1
  clientsByOffice[site].push(client)
end

clientsByOffice.keys.each do |site|
  puts "#{site} (#{clientsByOffice[site].length})"
  clientsByOffice[site].each do |client|
    puts "\t#{client['user']}"
  end
end
