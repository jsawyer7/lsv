ActiveAdmin.register_page "Data Tables" do
  menu label: "Data Tables", priority: 4

  content do
    div class: "materio-card" do
      div class: "materio-header" do
        h5 class: "mb-0 fw-semibold" do
          i class: "ri ri-book-2-line me-2"
          "Data Tables"
        end
      end
      div class: "card-body" do
        para "Browse and manage data tables: directions, languages, sources, books, canons, unit types, and text contents.", class: "text-muted"
      end
    end
  end
end


