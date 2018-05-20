=begin
%%{
  machine line_parser;

  newline = "\n";

  log_level_short = upper @{ log_level = fc };
  log_level_full = space* . upper+;

  date = digit{4} . '-' . digit{2} . '-' . digit{2};
  header_time = digit{2}. ':' . digit{2} . ':' . digit{2} . '.' .digit{6};
  header_datetime = (date . 'T' . header_time) >{ timestamp_start = p} @{ timestamp_end = p };

  pid = digit+ >{ pid_start = p } @{ pid_end = p };

  header = log_level_short . ', [' . header_datetime . ' #' . pid . '] ' . log_level_full . ' -- : ';

  http_method = 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE';
  uri = any+;
  ip = (digit+ . '.'){3} . digit+;
  started_time =  digit{2}. ':' . digit{2} . ':' . digit{2} . ' +' . digit{4};
  started_datetime = date . ' ' . started_time;
  started = header . 'Started ' . http_method . ' "' . uri . '" for ' . ip . ' at ' . started_datetime . newline;

  controller_name = (alnum | ':')+;
  action_name = (lower | '_')+;
  format = upper+;
  processing = header . 'Processing by ' . controller_name . '#' . action_name . ' as ' . format . newline;

  parameters = header . '  Parameters: {' . any* . '}' . newline;

  exec_time = digit+ . ('.' . digit+)? . 'ms';
  completed = header . 'Completed ' . digit+ . ' ' . upper+ . ' in ' . exec_time . ' (Views: ' . exec_time . ' | ActiveRecord: ' . exec_time . ')' . newline;

  user = header . 'User id: ' . digit+ . newline;

  error_header = header . newline;

  main := |*
    started @{ line_type = :started };
    processing @{ line_type = :processing };
    parameters @{ line_type = :parameters };
    completed @{ line_type = :completed };
    user @{ line_type = :user };
    error_header @{ line_type = :error_header };
  *|;
}%%
=end

class LineParser

  %% write data;

  # % Fix syntax highlighting
  def self.parse(data)

    data = data.unpack("c*") if(data.is_a?(String))
    p = 0
    pe = data.length
    eof = data.length

    %% write init;

    line_type = nil
    log_level = nil
    timestamp_start = timestamp_end = nil
    pid_start = pid_end = nil

    %% write exec;

    newline = "\n".unpack('c')[0]
    if p < pe
      line_type = :other
      while data[p] != newline && p < pe do
        p += 1
      end
      p += 1 if data[p] == newline && p < pe
    end

    timestamp = Time.parse(data[timestamp_start..timestamp_end].pack('c*')) if timestamp_end.present?
    pid = data[pid_start..pid_end].pack('c*').to_i if pid_end.present?

    [line_type, log_level, timestamp, pid]
  end
end
