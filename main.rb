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

Dir[
  File.dirname(__FILE__) + '/models/*.rb',
  File.dirname(__FILE__) + '/lib/*.rb'
].each {|file| require file }


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
  stats = { proxies: {}, qualities: {}, overall: {} }

  # get clients online by proxy
  JsonData.proxies.each do |proxy|
    stats[:proxies][proxy] = {}
    stats[:proxies][proxy][:online] = JsonData.online_count_by_proxy(proxy)
    stats[:proxies][proxy][:total] = JsonData.created_by_proxy(proxy).count
  end

  # get clients online by quality
  JsonData.qualities.each do |quality|
    stats[:qualities][quality] = {}
    stats[:qualities][quality][:online] = JsonData.online_count_by_quality(quality)
    stats[:qualities][quality][:total] = JsonData.created_by_quality(quality).count
  end

  # get total clients online
  stats[:overall][:online] = JsonData.online_count
  stats[:overall][:total] = JsonData.created.count

  JSON.pretty_generate(stats)
end

# Retrieve history of connected users by proxy
get '/api/stats/proxy' do
  stats = generate_stats_array(JsonData.proxies, 'nearIp', params[:timespan].to_i)
  JSON.pretty_generate(stats)
end

# Retrieve history of connected users by quality
get '/api/stats/quality' do
  stats = generate_stats_array(JsonData.qualities, 'name', params[:timespan].to_i)
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

  data = JsonData.new(data: json)

  if data.save
    return [ 201, 'data stored' ]
  else
    return [ 500, 'error storing data']
  end
end
