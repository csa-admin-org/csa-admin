# frozen_string_literal: true

require "sepa_file_parser"

module Billing
  class CamtFile
    class Parser
      Result = Data.define(:origin, :document)
      UnsupportedFileError = Class.new(StandardError) do
        attr_reader :original_error

        def initialize(original_error)
          @original_error = original_error
          super(original_error.message)
        end
      end

      def parse(file)
        camt = SepaFileParser::String.parse(file)
        case camt
        when SepaFileParser::Camt054::Base then Result.new("camt.054", camt)
        when SepaFileParser::Camt053::Base then Result.new("camt.053", camt)
        else
          raise UnsupportedFileError.new(StandardError.new("Invalid format: #{camt.class.name}"))
        end
      rescue SepaFileParser::Errors::UnsupportedNamespaceError, ArgumentError => e
        raise UnsupportedFileError.new(e)
      end
    end
  end
end
