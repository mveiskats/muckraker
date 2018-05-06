# Do database writes in batches for speed
class WriteBuffer
  FLUSH_THRESHOLD = 100

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
