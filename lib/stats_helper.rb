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
  events = JsonData.all_out_stream_by_timestamp

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
        # Add last entry again, so we get a stairs effect
        h[element] << [ timestamp - 1, h[element].last[1] ] unless h[element].empty?
        h[element] << [ timestamp, count ]
      else
        # Create a new array with the current series if element is empty
        h[element] = [[ timestamp, count ]]
      end
    end
  end

  now = Time.now.to_i * 1000
  elements.each do |element|
    # Skip if no data is available
    next unless h[element]

    # Add current timestamp with the same value as the last event
    h[element] << [ now, h[element].last[1] ]

    # If only a specific timespan is requested
    if timespan > 0

      # Collect data that matches the selected timespan
      data_in_timespan = []
      while h[element].last and h[element].last[0] > now - timespan * 1000
        data_in_timespan.unshift(h[element].pop)
      end

      # Get latest data to prepend to the beginning of the graph
      # If no data is left, use 0
      last = h[element].last ? h[element].last[1] : 0

      # Add last entry again, so we get a stairs effect
      data_in_timespan.unshift [ data_in_timespan.first[0] - 1, last ]
      data_in_timespan.unshift [ now - timespan * 1000, last ]

      # Update series
      h[element] = data_in_timespan
    end
  end

  # Convert hash to stats array
  h.each { |element, values| stats << { key: element, values: values } }
  stats
end
