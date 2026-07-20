# frozen_string_literal: true

module Security
  module Tools
    def self.all
      [
        BundlerAudit,
        Importmap,
        Brakeman,
        Aube
      ]
    end

    class BundlerAudit
      def name = :bundler_audit

      def command
        "bin/bundler-audit"
      end
    end

    class Importmap
      def name = :importmap

      def command
        "bin/importmap audit"
      end
    end

    class Brakeman
      def name = :brakeman

      def command
        if ENV["GITHUB_ACTIONS"]
          "bin/brakeman -f sarif -o results.sarif"
        else
          "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
        end
      end
    end

    # JS package advisories (aube registry audit).
    class Aube
      def name = :aube

      def command
        "aube audit"
      end
    end
  end
end
