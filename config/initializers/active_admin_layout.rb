# Override Active Admin's layout method to use our custom layout
Rails.application.config.to_prepare do
  # Override all Active Admin controllers
  ActiveAdmin::BaseController.class_eval do
    layout "active_admin_custom"

    # Override the layout method to ensure our layout is used
    def layout
      "active_admin_custom"
    end
  end

  ActiveAdmin::PageController.class_eval do
    layout "active_admin_custom"

    # Override the layout method to ensure our layout is used
    def layout
      "active_admin_custom"
    end
  end

  # Override resource controllers specifically
  ActiveAdmin::ResourceController.class_eval do
    layout "active_admin_custom"

    # Override the layout method to ensure our layout is used
    def layout
      "active_admin_custom"
    end
  end

  # Also override the main ActiveAdmin module
  ActiveAdmin.class_eval do
    def self.layout
      "active_admin_custom"
    end
  end

  # Force layout for all admin controllers
  Rails.application.config.to_prepare do
    if defined?(ActiveAdmin)
      ActiveAdmin.application.class_eval do
        def layout
          "active_admin_custom"
        end
      end
    end
  end
end
