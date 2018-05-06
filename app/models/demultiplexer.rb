# Compose log entries from log lines by pid
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
