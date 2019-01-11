# frozen_string_literal: true

module Issues
  class ImportCsvService
    def initialize(user, project, csv_io)
      @user = user
      @project = project
      @csv_io = csv_io
      @results = { success: 0, error_lines: [], parse_error: false }
    end

    def execute
      process_csv
      email_results_to_user

      @results
    end

    private

    def process_csv
      csv_data = @csv_io.open(&:read).force_encoding(Encoding::UTF_8)

      CSV.new(csv_data, col_sep: detect_col_sep(csv_data.lines.first), headers: true).each.with_index(2) do |row, line_no|
        issue = Issues::CreateService.new(@project, @user, title: row[0], description: row[1]).execute

        if issue.persisted?
          @results[:success] += 1
        else
          @results[:error_lines].push(line_no)
        end
      end
    rescue ArgumentError, CSV::MalformedCSVError
      @results[:parse_error] = true
    end

    def email_results_to_user
      Notify.import_issues_csv_email(@user.id, @project.id, @results).deliver_now
    end

    def detect_col_sep(header)
      if header.include?(",")
        ","
      elsif header.include?(";")
        ";"
      elsif header.include?("\t")
        "\t"
      else
        raise CSV::MalformedCSVError
      end
    end
  end
end
