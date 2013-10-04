# Generate statistics
# - Get all outStreamCreated and outStreamClosed events
# - Sort by timestamp
# - Get timestamp, field
#
# Returns Array:
# [
# { key: "<key>", values: [ [ timetstamp, count ] , [ timestamp, count ] ] },
# ]
def generate_stats_array(elements, field, timespan=0)
  stats = []
  events = JsonData.since(timespan).all_out_stream_by_timestamp

  h = {}
  events.each do |event|
    # Javascript timestamp is in ms, so multiply by 1000
    timestamp = event['data']['timestamp'] * 1000

    elements.each do |element|
      # Get last count, initialize with 0 if not existent
      if h[element]
        count = h[element].last[1]
      else
        count = 0
      end

      # In case the entry is concerning this element
      # increment/decrement counter accordingly
      field_to_check = event[field] || event['data']['payload'][field]

      if field_to_check == element
        count += 1 if event['data']['type'] == 'outStreamCreated'
        count -= 1 if event['data']['type'] == 'outStreamClosed'
      end

      if h[element]
        h[element] << [ timestamp, count ] unless h[element].last[0] == timestamp
      else
        h[element] = [[ timestamp, count ]]
      end
    end
  end

  # Add current timestamp with the same value as the last event
  now = Time.now.to_i * 1000
  elements.each { |element| h[element] << [ now, h[element].last[1] ] }

  # Convert hash to stats array
  h.each { |element, values| stats << { key: element, values: values } }
  stats
end
