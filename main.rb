require 'sinatra'
require 'mongoid'
require 'json'
require 'date'
require 'haml'

# Configure Sinatra
configure do
  set :server, :puma
  set :port, 9001
  set :environment, :production
end

# Connect to MongoDB
Mongoid.load!('config/mongoid.yml', :production)

Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file }


# Display default front page
get '/' do
  haml :index
end

# Return JSON with currently online clients by proxy and quality, as well as total
# {
#   "proxies": { "10.229.67.61": 4 },
#   "qualities": { "sublan_360p500k": 1, "sublan_576p1000k": 1, "sublan_720p2000k": 2 },
#   "total": 4
# }
get '/api/online' do
  data = { proxies: {}, qualities: {} }

  # get clients online by proxy
  JsonData.proxies.each { |proxy| data[:proxies][proxy] = JsonData.online_count_by_proxy(proxy) }

  # get clients online by quality
  JsonData.qualities.each { |quality| data[:qualities][quality] = JsonData.online_count_by_quality(quality) }

  # get total clients online
  data[:total] = data[:proxies].values.inject { |sum,x| sum + x }

  JSON.pretty_generate(data)
end

# Retrieve history of connected users by proxy
# - Get all outStreamCreated and outStreamClosed events
# - Sort by timestamp
# - Get timestamp, nearIp
#
# Returns JSON:
# [
# { key: "10.13.37.1", values: [ [ timetstamp, count ] , [ timestamp, count ] ] },
# ]
get '/api/stats/proxy' do
  stats = []
  proxies = JsonData.proxies
  events = JsonData.all_out_stream_by_timestamp

  h = {}
  events.each do |event|
    # Javascript timestamp is in ms, so multiply by 1000
    timestamp = event['data']['timestamp'] * 1000

    proxies.each do |proxy|
      # Get last count, initialize with 0 if not existent
      if h[proxy]
        count = h[proxy].last[1]
      else
        count = 0
      end

      # In case the entry is concerning this proxy
      # increment/decrement counter accordingly
      if event['data']['payload']['nearIp'] == proxy
        count += 1 if event['data']['type'] == 'outStreamCreated'
        count -= 1 if event['data']['type'] == 'outStreamClosed'
      end

      if h[proxy]
        h[proxy] << [ timestamp, count ] unless h[proxy].last[0] == timestamp
      else
        h[proxy] = [[ timestamp, count ]]
      end
    end
  end

  # Convert hash to stats array
  h.each { |proxy, values| stats << { key: proxy, values: values } }

  JSON.pretty_generate(stats)
end

# Retrieve history of connected users by quality
# - Get all outStreamCreated and outStreamClosed events
# - Sort by timestamp
# - Get timestamp, name
#
# Returns JSON:
# [
# { key: "sublan_360p500k", values: [ [ timetstamp, count ] , [ timestamp, count ] ] },
# ]
get '/api/stats/quality' do
  stats = []
  qualities = JsonData.qualities
  events = JsonData.all_out_stream_by_timestamp

  h = {}
  events.each do |event|
    # Javascript timestamp is in ms, so multiply by 1000
    timestamp = event['data']['timestamp'] * 1000

    qualities.each do |quality|
      # Get last count, initialize with 0 if not existent
      if h[quality]
        count = h[quality].last[1]
      else
        count = 0
      end

      # In case the entry is concerning this quality
      # increment/decrement counter accordingly
      if event['data']['payload']['name'] == quality
        count += 1 if event['data']['type'] == 'outStreamCreated'
        count -= 1 if event['data']['type'] == 'outStreamClosed'
      end

      if h[quality]
        h[quality] << [ timestamp, count ] unless h[quality].last[0] == timestamp
      else
        h[quality] = [[ timestamp, count ]]
      end
    end
  end

  # Convert hash to stats array
  h.each { |quality, values| stats << { key: quality, values: values } }

  JSON.pretty_generate(stats)
end


# Debug frontpage
get '/api/debug' do
  @count = JsonData.count
  @last = JsonData.last

  haml :debug_index
end

# API for doing debugging queries
# e.g.
# /api/debug/query?data.payload.customData=proxy&data.type=outStreamCreated
get '/api/debug/query' do
  search = {}
  params.each do |k, v|
    # Convert integers to int
    search[k] = v.match(/^\d+$/) ? v.to_i : v
  end

  @data = JsonData.where(search)
  @count = @data.count
  @filter = search.inspect

  haml :debug_json
end

# Retrieve statistics
get '/api/debug/stats' do
  data = {
    clients: {},
    qualities: {},
    average_uptime_by_ip: JsonData.average_uptime_by_ip,
  }

  JsonData.closed_clients.each do |client|
    data[:clients][client] ||= {}
    data[:clients][client][:upTime] = JsonData.uptime_by_client(client)
    data[:clients][client][:qualities] ||= {}
    JsonData.qualities_by_client(client).each do |quality|
      data[:clients][client][:qualities][quality] = JsonData.uptime_by_quality(quality).to_i
    end
  end

  JsonData.qualities.each do |quality|
    data[:qualities][quality] ||= {}
    data[:qualities][quality][:upTime] = JsonData.uptime_by_quality(quality).to_i
  end

  @data = JSON.pretty_generate(data)

  haml :debug_json
end


# Collects events (JSON bodies) and stores them in MongoDB
post '/api/collect' do
  content_type :json

  begin
    json = JSON.parse(request.body.read.to_s)
  rescue JSON::ParserError
    return [ 400, 'invalid json' ]
  end

  data = JsonData.new(created_at: DateTime.now, data: json)

  if data.save
    return [ 201, 'data stored' ]
  else
    return [ 500, 'error storing data']
  end
end
