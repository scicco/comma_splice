module CommaSplice
  class FileCorrector
    attr_reader :file_contents, :csv_content, :start_line, :end_line, :start_column, :end_column

    def initialize(file_path, start_line: nil, end_line:nil, start_column: nil, end_column: nil)
      @file_path       = file_path
      @file_contents   = File.read(file_path, encoding: 'utf-8')

      @content_finder = ContentFinder.new(@file_contents, start_line, end_line)
      @csv_content   = @content_finder.content
      @start_line    = @content_finder.start_line
      @end_line      = @content_finder.start_line

      if start_column && end_column
        @start_column = start_column
        @end_column = end_column
      else
        finder = VariableColumnFinder.new(@csv_content[0], @csv_content[1..-1])
        @start_column = finder.start_column
        @end_column = finder.end_column
      end

      raise CommaSplice::Error, "empty contents #{file_path}" unless @csv_content.present?
    end

    def header
      @header ||= Line.new(csv_content.first)
    end

    def bad_lines
      line_correctors.select(&:needs_correcting?).collect(&:original)
    end

    def needs_correcting?
      bad_lines.size.positive?
    end

    def corrected
      @corrected ||= [
        @file_contents.lines[0, @start_line],
        corrected_lines,
        @file_contents.lines[@end_line, -1]
      ].flatten
    end

    def save!
      save(@file_path)
    end

    def save(path)
      File.open(path, 'w+') do |f|
        corrected.each_with_index do |line, index|
          # don't add an extra line break at the end
          f.puts line if corrected.size > index && line
        end
      end
    end

    def to_json
      @content_finder.parsed.try(:to_json)
    end

    private

    def line_correctors
      @line_correctors ||= csv_content.collect do |line|
        LineCorrector.new(header, Line.new(line), @start_column, @end_column)
      end
    end

    def corrected_lines
      line_correctors.collect do |line|
        if line.needs_correcting?
          line.corrected
        else
          line.original
        end
      end
    end
  end
end
