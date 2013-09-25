class JsonData
  include Mongoid::Document
  field :data,       type: Hash
  field :created_at, type: DateTime

  def self.created
    where(
      'data.payload.customData' => 'proxy',
      'data.type' => 'outStreamCreated',
    )
  end

  def self.closed
    where(
      'data.payload.customData' => 'proxy',
      'data.type' => 'outStreamClosed',
    )
  end

  def self.online_count
    created.count - closed.count
  end


  def self.proxies
    created.distinct('data.payload.nearIp')
  end

  def self.created_by_proxy(proxy)
    created.where('data.payload.nearIp' => proxy)
  end

  def self.closed_by_proxy(proxy)
    closed.where('data.payload.nearIp' => proxy)
  end

  def self.online_count_by_proxy(proxy)
    created_by_proxy(proxy).count - closed_by_proxy(proxy).count
  end


  def self.qualities
    created.distinct('data.payload.name')
  end

  def self.created_by_quality(quality)
    created.where('data.payload.name' => quality)
  end

  def self.closed_by_quality(quality)
    closed.where('data.payload.name' => quality)
  end

  def self.online_count_by_quality(quality)
    created_by_quality(quality).count - closed_by_quality(quality).count
  end


  def self.client_ips
    created.distinct('data.payload.farIp')
  end

  def self.created_by_client_ip(client_ip)
    created.where('data.payload.farIp' => client_ip)
  end

  def self.closed_by_client_ip(client_ip)
    closed.where('data.payload.farIp' => client_ip)
  end

  def self.online_count_by_client_ip(client_ip)
    created_by_client_ip(client_ip).count - closed_by_client_ip(client_ip).count
  end


  def self.sort_by_quality
    asc('data.payload.name')
  end

  def self.sort_by_proxy
    asc('data.payload.nearIp')
  end

  def self.sort_by_client
    asc('data.payload.farIp')
  end

  def self.all_out_stream_by_timestamp
    where('data.payload.customData' => 'proxy').any_of({ 'data.type' => 'outStreamCreated' }, { 'data.type' => 'outStreamClosed' }).asc('data.timestamp')
  end


  def self.closed_clients
    closed.distinct('data.payload.farIp')
  end

  def self.uptime_by_client(client)
    closed.where('data.payload.farIp' => client).sum('data.payload.upTime').to_i
  end

  def self.qualities_by_client(client)
    closed.where('data.payload.farIp' => client).qualities
  end

  def self.uptime_by_quality(quality)
    closed.where('data.payload.name' => quality).sum('data.payload.upTime').to_i
  end

  def self.average_uptime_by_ip
    total_uptime = 0

    c = closed_clients
    c.each do |client|
      total_uptime += uptime_by_client(client)
    end

    total_uptime / c.count
  end
end
