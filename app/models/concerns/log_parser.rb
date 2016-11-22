module LogParser
  # Do database writes in batches for speed
  class WriteBuffer
    FLUSH_THRESHOLD = 1000

    def initialize
      @bulk_entries = []
    end

    def <<(entry)
      @bulk_entries << entry
      flush if @bulk_entries.length >= FLUSH_THRESHOLD
    end

    def flush
      LogEntry.import @bulk_entries
      @bulk_entries = []
    end
  end

  # Log lines need to be sorted into separate buffers by pid
  # because lines of log messages from different processes can intermix
  class Demultiplexer
    def initialize
      @pid_map = {}
      @write_buffer = WriteBuffer.new
    end

    def [](pid)
      @pid_map[pid]
    end

    def new_entry(pid, attributes)
      @write_buffer << @pid_map[pid] if @pid_map[pid].present?
      @pid_map[pid] = LogEntry.new attributes.merge(pid: pid)
    end

    # Assigns named matches of MatchData to attributes of record
    def merge_match(pid, match_data)
      entry = @pid_map[pid]
      return if entry.nil?

      match_data.names.each do |match_name|
        entry[match_name] = match_data[match_name]
      end
    end

    def flush
      @pid_map.values.each { |entry| @write_buffer << entry }
      @write_buffer.flush
    end
  end

  def self.import_file(file_name)
    # Turning off debug logging can shave off about 25% of import time
    old_log_level = Rails.logger.level
    Rails.logger.level = 1 if Rails.logger.level == 0

    import_start = Time.now

    buffer = WriteBuffer.new

    # TODO: Figure out a decent way to fit this into 80 char column width
    line_rx = /^(\w), \[(.+) #(\d+)\] .+ -- : (.*)$/
    started_rx = /^Started (?<method>\w+) "(?<uri>.+)" for (?<ip>.+) at/
    processing_rx = /^Processing by (?<controller>.+)#(?<action>.+) as (?<format>.+)/
    parameters_rx = /^  Parameters: (?<parameters>\{.+\})/
    completed_rx = /^Completed (?<status_code>\d+) \w+ in (?<response_time>\d+)ms \(Views: (?<view_time>.+)ms \| ActiveRecord: (?<activerecord_time>.+)ms\)/
    user_rx = /^User id: (?<user_id>\d+)/

    demux = Demultiplexer.new

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

    import_duration = sprintf('%.2f', Time.now - import_start)
    Rails.logger.info "Imported file #{file_name} in #{import_duration} seconds"

  ensure
    Rails.logger.level = old_log_level
  end

  def self.import_files(pattern)
    Dir[pattern].each { |fname| import_file(fname) }
  end
end
