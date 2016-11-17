module Handlers
  class PersistHandler < Base

    def call(context)
      update_database(context)
      @app.call(context)
    end

    protected

    def update_database(context)
    end
  end
end