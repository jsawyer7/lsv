module Verifaith
  class ValidatorResult
    attr_reader :ok, :errors, :warnings, :flags, :meta

    def initialize(ok:, errors: [], warnings: [], flags: [], meta: {})
      @ok = ok
      @errors = Array(errors)
      @warnings = Array(warnings)
      @flags = Array(flags)
      @meta = meta || {}
    end

    def ok?
      @ok
    end

    def merge!(other)
      return self unless other

      @errors.concat(Array(other.errors))
      @warnings.concat(Array(other.warnings))
      @flags.concat(Array(other.flags))
      @meta.merge!(other.meta || {})
      @ok = @errors.empty?
      self
    end

    def self.ok(meta: {})
      new(ok: true, meta: meta)
    end

    def self.fail(errors:, flags: [], meta: {})
      new(ok: false, errors: Array(errors), flags: Array(flags), meta: meta)
    end

    def self.warn(warnings:, flags: [], meta: {})
      new(ok: true, warnings: Array(warnings), flags: Array(flags), meta: meta)
    end
  end
end



