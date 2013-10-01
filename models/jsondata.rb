class JsonData
  include Mongoid::Document
  include Mongoid::Timestamps

  field :data, type: Hash
  field :ip,   type: String


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

  def self.since(seconds=0)
    return all if seconds == 0
    where(:created_at.gte => (Time.now - seconds))
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

  def self.proxy_active?(proxy)
    count = where(
      :ip => proxy,
      :created_at.gte => (Time.now - 30)
    ).count

    return true if count > 0
    false
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


  def self.sort_by_quality
    asc('data.payload.name')
  end

  def self.sort_by_proxy
    asc('data.payload.nearIp')
  end

  def self.all_out_stream_by_timestamp
    where('data.payload.customData' => 'proxy').any_of({ 'data.type' => 'outStreamCreated' }, { 'data.type' => 'outStreamClosed' }).asc('data.timestamp')
  end


  def self.uptime_by_quality(quality)
    closed.where('data.payload.name' => quality).sum('data.payload.upTime').to_i
  end
end
