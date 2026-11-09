#!/usr/bin/ruby
# Read-only App Store numbers for Stamped. Only sends GET requests.
# Usage: ruby asc_report.rb [days]   (default 28)
require 'openssl'
require 'json'
require 'net/http'
require 'uri'
require 'base64'
require 'zlib'
require 'stringio'
require 'date'
require 'csv'

KEY_ID  = 'XA76LTRH84'
ISSUER  = 'd2514eb9-1b53-40fa-8a28-c685ad3bed94'
KEY     = File.expand_path("~/.appstoreconnect/private_keys/AuthKey_#{KEY_ID}.p8")
ONGOING = '74eb4fc9-14f7-411c-9ed7-478369a59700'
DAYS    = (ARGV[0] || 28).to_i
SINCE   = Date.today - DAYS

def b64(s)
  Base64.urlsafe_encode64(s, padding: false)
end

def token
  head = b64({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' }.to_json)
  body = b64({ iss: ISSUER, aud: 'appstoreconnect-v1', exp: Time.now.to_i + 1000 }.to_json)
  data = "#{head}.#{body}"
  der  = OpenSSL::PKey.read(File.read(KEY)).sign(OpenSSL::Digest.new('SHA256'), data)
  r, s = OpenSSL::ASN1.decode(der).value.map { |v| v.value.to_s(2).rjust(32, "\0")[-32, 32] }
  "#{data}.#{b64(r + s)}"
end

TOKEN = token

def fetch(url, auth: true)
  uri = URI(url)
  req = Net::HTTP::Get.new(uri)
  req['Authorization'] = "Bearer #{TOKEN}" if auth
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
  abort "HTTP #{res.code} for #{uri.path}: #{res.body[0, 200]}" unless res.is_a?(Net::HTTPSuccess)
  res.body
end

def api(path)
  JSON.parse(fetch(path.start_with?('http') ? path : "https://api.appstoreconnect.apple.com#{path}"))
end

def all(path)
  out = []
  while path
    page = api(path)
    out.concat(page['data'])
    path = page.dig('links', 'next')
  end
  out
end

def rows_for(report)
  rows = []
  instances = all("/v1/analyticsReports/#{report['id']}/instances?filter[granularity]=DAILY&limit=200")
  instances.select { |i| Date.parse(i['attributes']['processingDate']) >= SINCE }.each do |inst|
    all("/v1/analyticsReportInstances/#{inst['id']}/segments").each do |seg|
      raw = fetch(seg['attributes']['url'], auth: false)
      text = Zlib::GzipReader.new(StringIO.new(raw)).read
      CSV.parse(text, headers: true, col_sep: "\t", liberal_parsing: true) { |r| rows << r.to_h }
    end
  end
  rows.select { |r| r['Date'] && Date.parse(r['Date']) >= SINCE }
end

def sum_by(rows, *keys, field)
  rows.group_by { |r| keys.map { |k| r[k] } }
      .map { |k, v| [k.join(' / '), v.sum { |r| r[field].to_f }.round] }
      .sort_by { |_, n| -n }
end

def print_table(title, pairs, limit = 10)
  puts "\n#{title}"
  puts '  (no data)' if pairs.empty?
  pairs.first(limit).each { |k, n| puts "  #{n.to_s.rjust(7)}  #{k}" }
end

reports = all("/v1/analyticsReportRequests/#{ONGOING}/reports?limit=200")
find = ->(name) { reports.find { |r| r['attributes']['name'] == name } }
puts "App Store, last #{DAYS} days (since #{SINCE}). Apple's data runs a few days behind."

if (dl = find.call('App Downloads Standard'))
  rows = rows_for(dl)
  puts "Latest day in data: #{rows.map { |r| r['Date'] }.max}"
  print_table('Downloads by type', sum_by(rows, 'Download Type', 'Counts'))
  print_table('Downloads by source', sum_by(rows, 'Source Type', 'Counts'))
  print_table('Downloads by campaign', sum_by(rows.reject { |r| [nil, '', 'null'].include?(r['Campaign']) }, 'Campaign', 'Counts'))
  first = rows.select { |r| r['Download Type'] == 'First-time download' }
  print_table('First-time downloads by device', sum_by(first, 'Device', 'Counts'))
  print_table('First-time downloads by source', sum_by(first, 'Source Type', 'Counts'))
  print_table('First-time downloads by territory', sum_by(first, 'Territory', 'Counts'))
  days = first.group_by { |r| r['Date'] }.sort.map { |d, v| [d, v.sum { |r| r['Counts'].to_f }.round] }
  print_table('First-time downloads by day', days, 40)
end

if (eng = find.call('App Store Discovery and Engagement Standard'))
  rows = rows_for(eng)
  print_table('Store page events', sum_by(rows, 'Event', 'Counts'))
  print_table('Page views by source', sum_by(rows.select { |r| r['Event'] == 'Page view' }, 'Source Type', 'Counts'))
end

if (ses = find.call('App Sessions Standard'))
  rows = rows_for(ses)
  print_table('Sessions by platform', sum_by(rows, 'Device', 'Sessions'))
end
