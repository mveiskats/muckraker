begin
  source = File.join(Rails.root, 'app/models/line_parser.rl')
  destination = File.join(Rails.root, 'tmp/line_parser.rb')
  compiled = system("ragel -R -o #{destination} #{source}")

  raise 'Ragel error' unless compiled

  load destination
end
