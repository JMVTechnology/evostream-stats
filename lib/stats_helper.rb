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
        # Add new timestamp, unless this timestamp already exists
        h[element] << [ timestamp, count ] unless h[element].last[0] == timestamp
      else
        # Create a new array with the current series if element is empty
        h[element] = [[ timestamp, count ]]
      end
    end
  end

  now = Time.now.to_i * 1000
  elements.each do |element|
    # Remove data that doesn't match the selected timespan
    h[element].delete_if { |a| a[0] < now - timespan * 1000 } if timespan > 0

    # Delete this element if no data is left
    if h[element].empty?
      h.delete(element)

    # Otherwise, add current timestamp with the same value as the last event
    else
      h[element] << [ now, h[element].last[1] ]
    end
  end

  # Convert hash to stats array
  h.each { |element, values| stats << { key: element, values: values } }
  stats
end
