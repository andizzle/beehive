module Fleet

  Headlines = [
    'Time taken for tests',
    'Complete requests',
    'Failed requests',
    'Non-2xx responses',
    'Total transferred',
    'HTML transferred',
    'Requests per second',
    'Time per request',
    'Transfer rate'
  ]

  def Fleet.print_report(result)
    result.each do |key, value|
      puts '%s: %s' % [key, value.join(' ')]
    end
  end

  # merge all results together and with certain calculations
  def Fleet.report(data)
    result = {}

    # hash
    data.each_value do |entries|
      entries.each do |key, value|

        if result.has_key? key
          result[key][0] << value.first.to_f
        else
          result[key] = value.size == 1 ? [[value.first.to_f]] : [[value.first.to_f], value.last]
        end

      end
    end

    # process the result data, e.g, sum and avg
    result.each do |key, value|
      #puts value.to_s
      if ['Time taken for tests'].include? key
        value[0] = value[0].sort.last
      elsif ['Complete requests', 'Failed requests', 'Total transferred', 'HTML transferred', 'Non-2xx responses'].include? key
        value[0] = value[0].inject{|sum, x| sum + x}
      else
        count = value[0].count
        value[0] = (value[0].inject{|sum, x| sum + x} / count).round(2)
      end
      result[key] = value
    end
    result
  end


  def Fleet.parse_ab_data(data)
    result = {}

    # parse each line with the matched heading
    data.each_line do |line|
      if line.start_with?(*Headlines)
        parts = line.partition(':')
        head = parts.first
        body = parts.last.strip.split(' ', 2)
        result[head] = body
      end
    end

    result
  end

end
