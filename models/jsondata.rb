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

  def self.servers
    created.distinct('data.payload.nearIp')
  end

  def self.created_by_server(server)
    created.where('data.payload.nearIp' => server)
  end

  def self.closed_by_server(server)
    closed.where('data.payload.nearIp' => server)
  end

  def self.online_count_by_server(server)
    created_by_server(server).count - closed_by_server(server).count
  end

  def self.server_active?(server)
    count = where(
      :ip => server,
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

  def self.sort_by_server
    asc('data.payload.nearIp')
  end

  def self.all_out_stream_by_timestamp
    where('data.payload.customData' => 'proxy').any_of({ 'data.type' => 'outStreamCreated' }, { 'data.type' => 'outStreamClosed' }).asc('data.timestamp')
  end


  def self.uptime_by_quality(quality)
    closed.where('data.payload.name' => quality).sum('data.payload.upTime').to_i
  end
end
