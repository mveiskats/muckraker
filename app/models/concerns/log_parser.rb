module LogParser
  # Assigns named matches of MatchData to attributes of record
  def self.merge_match_into_record(match_data, record)
    match_data.names.each do |match_name|
      record[match_name] = match_data[match_name]
    end
  end

  def self.import_file(file_name)
    # Turning off debug logging can shave off about 25% of import time
    old_log_level = Rails.logger.level
    Rails.logger.level = 1 if Rails.logger.level == 0

    import_start = Time.now

    # TODO: Figure out a decent way to fit this into 80 char column width
    line_rx = /^(\w), \[(.+) #(\d+)\] .+ -- : (.*)$/
    started_rx = /^Started (?<method>\w+) "(?<uri>.+)" for (?<ip>.+) at/
    processing_rx = /^Processing by (?<controller>.+)#(?<action>.+) as (?<format>.+)/
    parameters_rx = /^  Parameters: (?<parameters>\{.+\})/
    completed_rx = /^Completed (?<status_code>\d+) \w+ in (?<response_time>\d+)ms \(Views: (?<view_time>.+)ms \| ActiveRecord: (?<activerecord_time>.+)ms\)/

    # Accumulate input through separate buffers for each pid,
    # because log messages from different processes can intermix
    buffer = {}

    # Keep track of last known pid,
    # because some messages (exceptions) span multiple lines
    # with prefix only on the first one
    last_pid = nil

    # Following code will rely on the fact that regexps matched with =~
    # assign their named captures to local variables
    File.open(file_name).each do |line|
      if match = line_rx.match(line)
        log_level, logged_at, pid, line_data = match.captures
        last_pid = pid
        entry = buffer[pid]

        if match = started_rx.match(line_data)
          buffer[pid].save if buffer[pid].present?
          buffer[pid] = LogEntry.new logged_at: logged_at, pid: pid, content: ''
          entry = buffer[pid]
          merge_match_into_record(match, entry)

          begin
            uri = URI.parse(entry.uri)
            entry.uri_path = uri.path
            entry.uri_query = uri.query
            entry.uri_fragment = uri.fragment
          rescue URI::InvalidURIError
            Rails.logger.warn "Failed to parse invalid URI: #{entry.uri}"
          end

        elsif match = processing_rx.match(line_data)
          merge_match_into_record(match, entry)
        elsif match = parameters_rx.match(line_data)
          merge_match_into_record(match, entry)
        elsif match = completed_rx.match(line_data)
          merge_match_into_record(match, entry)
        end

        if entry.present?
          entry.content += line

          if log_level == 'F'
            # Mark exception as non-nil, so following lines get collected
            entry.exception = ''
          end
        end
      else
        entry = buffer[last_pid]

        entry.content += line
        entry.exception += line unless entry.exception.nil?
      end
    end

    buffer.values.each &:save

    import_duration = sprintf('%.2f', Time.now - import_start)
    Rails.logger.info "Imported file #{file_name} in #{import_duration} seconds"

  ensure
    Rails.logger.level = old_log_level
  end

  def self.import_files(pattern)
    Dir[pattern].each { |fname| import_file(fname) }
  end
end
