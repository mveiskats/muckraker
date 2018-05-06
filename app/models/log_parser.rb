module LogParser
  def self.without_logs
    # Turning off debug logging can shave off about 25% of import time
    old_log_level = Rails.logger.level
    Rails.logger.level = 1 if Rails.logger.level.zero?

    yield
  ensure
    Rails.logger.level = old_log_level
  end

  # Log lines need to be sorted into separate buffers by pid
  # because lines of log messages from different processes can intermix
  def self.import_file(file_name)
    # TODO: Figure out a decent way to fit this into 80 char column width
    line_rx = /^(\w), \[(.+) #(\d+)\] .+ -- : (.*)$/

    started_rx = /^Started (?<method>\w+) "(?<uri>.+)" for (?<ip>.+) at/
    processing_rx = /^Processing by (?<controller>.+)#(?<action>.+) as (?<format>.+)/
    parameters_rx = /^  Parameters: (?<parameters>\{.+\})/
    completed_rx = /^Completed (?<status_code>\d+) \w+ in (?<response_time>\d+)ms \(Views: (?<view_time>.+)ms \| ActiveRecord: (?<activerecord_time>.+)ms\)/
    user_rx = /^User id: (?<user_id>\d+)/

    demux = Demultiplexer.new

    # Keep track of last known pid,
    # because some messages span multiple lines
    # with prefix only on the first one
    last_pid = nil

    File.open(file_name).each do |line|
      if match = line_rx.match(line)
        log_level, logged_at, pid, line_data = match.captures
        last_pid = pid

        if match = started_rx.match(line_data)
          entry = demux.new_entry(pid, logged_at: logged_at, content: '')
          demux.merge_match(pid, match)

          begin
            uri = URI.parse(entry.uri)
            entry.uri_path = uri.path
            entry.uri_query = uri.query
            entry.uri_fragment = uri.fragment
          rescue URI::InvalidURIError
            Rails.logger.warn "Failed to parse invalid URI: #{entry.uri}"
          end

        elsif match = processing_rx.match(line_data)
          demux.merge_match(pid, match)
        elsif match = parameters_rx.match(line_data)
          demux.merge_match(pid, match)
        elsif match = completed_rx.match(line_data)
          demux.merge_match(pid, match)
        elsif match = user_rx.match(line_data)
          demux.merge_match(pid, match)
        end

        entry = demux[pid]

        if entry.present?
          entry.content += line

          if log_level == 'F'
            # Mark exception as non-nil, so following lines get collected
            entry.exception = ''
          end
        end
      else
        entry = demux[last_pid]

        if entry.present?
          entry.content += line
          entry.exception += line unless entry.exception.nil?
        end
      end
    end

    demux.flush
  end

  def self.import_files(pattern)
    without_logs do
      Dir[pattern].each do |fname|
        start = Time.now

        import_file(fname)

        duration = format('%.2f', Time.now - start)
        Rails.logger.info "Imported file #{file_name} in #{duration} seconds"
      end
    end
  end
end
