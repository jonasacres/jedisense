#!/usr/bin/ruby

require 'json'
require 'net/https'

uri = URI.parse('https://presence.a4sw.co:3310/people')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

req = Net::HTTP::Get.new(uri.request_uri)
if ARGV.length >= 1 then
  req.add_field("Authorization", "Bearer #{ARGV[0]}")
end

res = http.request(req)

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
