ActiveAdmin.register CanonBookInclusion do
  permit_params :canon_id, :work_code, :include_from, :include_to, :notes

  # Custom page title
  menu label: "Canon Inclusions", priority: 10

  # Disable default show and edit actions completely
  actions :all, except: [:show, :edit]

  # Override the find_resource method to handle composite primary keys
  controller do
    def find_resource
      # Parse the composite primary key from params[:id]
      id_part = params[:id]

      if id_part && id_part.include?('-')
        canon_id, work_code = id_part.split('-', 2)
        resource_class.find_by(canon_id: canon_id.to_i, work_code: work_code)
      elsif id_part && id_part.include?('.')
        canon_id, work_code = id_part.split('.', 2)
        resource_class.find_by(canon_id: canon_id.to_i, work_code: work_code)
      else
        # If no separator found, this is an invalid request for composite primary key
        raise ActiveRecord::RecordNotFound, "Invalid composite key format. Expected format: canon_id-work_code or canon_id.work_code"
      end
    end

    # Override the show method to handle composite primary keys properly
    def show
      @canon_book_inclusion = find_resource
      raise ActiveRecord::RecordNotFound unless @canon_book_inclusion

      # Set the resource for Active Admin
      @resource = @canon_book_inclusion

      # Render our custom show content directly
      render inline: show_page_content, layout: "active_admin_custom"
    end

    # Override the edit method to handle composite primary keys properly
    def edit
      @canon_book_inclusion = find_resource
      raise ActiveRecord::RecordNotFound unless @canon_book_inclusion

      # Set the resource for Active Admin
      @resource = @canon_book_inclusion

      # Render our custom edit content directly
      render inline: edit_page_content, layout: "active_admin_custom"
    end

    # Override the update method to handle composite primary keys properly
    def update
      # Parse the composite primary key from params[:id]
      id_part = params[:id]

      if id_part && id_part.include?('-')
        canon_id, work_code = id_part.split('-', 2)
        @canon_book_inclusion = resource_class.find_by(canon_id: canon_id.to_i, work_code: work_code)
      elsif id_part && id_part.include?('.')
        canon_id, work_code = id_part.split('.', 2)
        @canon_book_inclusion = resource_class.find_by(canon_id: canon_id.to_i, work_code: work_code)
      else
        raise ActiveRecord::RecordNotFound, "Invalid composite key format"
      end

      raise ActiveRecord::RecordNotFound unless @canon_book_inclusion

      # Update the record using raw SQL to avoid composite primary key issues
      params = canon_book_inclusion_params
      update_sql = <<~SQL
        UPDATE canon_book_inclusions
        SET include_from = $1, include_to = $2, notes = $3, updated_at = $4
        WHERE canon_id = $5 AND work_code = $6
      SQL

      ActiveRecord::Base.connection.exec_query(
        update_sql,
        'SQL',
        [
          params[:include_from],
          params[:include_to],
          params[:notes],
          Time.current,
          canon_id.to_i,
          work_code
        ]
      )

      # Check if the record still exists (update was successful)
      updated_record = resource_class.find_by(canon_id: canon_id.to_i, work_code: work_code)
      if updated_record
        redirect_to admin_canon_book_inclusion_path("#{canon_id}-#{work_code}"), notice: 'Canon book inclusion was successfully updated.'
      else
        @canon_book_inclusion = resource_class.find_by(canon_id: canon_id.to_i, work_code: work_code)
        @resource = @canon_book_inclusion
        render inline: edit_page_content, layout: "active_admin_custom"
      end
    end

    # Override the destroy method to handle composite primary keys properly
    def destroy
      # Parse the composite primary key from params[:id]
      id_part = params[:id]

      if id_part && id_part.include?('-')
        canon_id, work_code = id_part.split('-', 2)
        @canon_book_inclusion = resource_class.find_by(canon_id: canon_id.to_i, work_code: work_code)
      elsif id_part && id_part.include?('.')
        canon_id, work_code = id_part.split('.', 2)
        @canon_book_inclusion = resource_class.find_by(canon_id: canon_id.to_i, work_code: work_code)
      else
        raise ActiveRecord::RecordNotFound, "Invalid composite key format"
      end

      raise ActiveRecord::RecordNotFound unless @canon_book_inclusion

      # Use raw SQL to delete the record with composite primary key
      delete_sql = <<~SQL
        DELETE FROM canon_book_inclusions
        WHERE canon_id = $1 AND work_code = $2
      SQL

      ActiveRecord::Base.connection.exec_query(
        delete_sql,
        'SQL',
        [canon_id.to_i, work_code]
      )

      redirect_to admin_canon_book_inclusions_path, notice: 'Canon book inclusion was successfully deleted.'
    end

    private

    def canon_book_inclusion_params
      params.require(:canon_book_inclusion).permit(:canon_id, :work_code, :include_from, :include_to, :notes)
    end

    def edit_page_content
      <<~HTML

        <div class="page-header mb-4">
          <div class="d-flex justify-content-between align-items-center">
            <div>
              <h1 class="mb-2 text-primary">Edit Canon Book Inclusion</h1>
              <p class="text-muted mb-0">Update canon book inclusion settings</p>
            </div>
            <div>
              <a href="#{admin_canon_book_inclusions_path}" class="btn btn-outline-secondary">Back to Canon Inclusions</a>
            </div>
          </div>
        </div>

        <form action="#{admin_canon_book_inclusion_path("#{@canon_book_inclusion.canon_id}-#{@canon_book_inclusion.work_code}")}" method="post" class="card">
          <input type="hidden" name="_method" value="patch">
          <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">

          <div class="card-header bg-primary text-white">
            <h5 class="mb-0">
              <i class="ri ri-edit-line me-2"></i>
              Inclusion Information
            </h5>
          </div>
          <div class="card-body p-4">
            <div class="materio-form-group">
              <div class="materio-form-label">
                <i class="ri ri-book-line me-2"></i>
                <span>Canon</span>
              </div>
              <select name="canon_book_inclusion[canon_id]" class="materio-form-control">
                #{Canon.all.map { |c| "<option value='#{c.id}' #{'selected' if c.id == @canon_book_inclusion.canon_id}>#{c.name}</option>" }.join}
              </select>
            </div>

            <div class="materio-form-group">
              <div class="materio-form-label">
                <i class="ri ri-code-line me-2"></i>
                <span>Work Code</span>
              </div>
              <input type="text" name="canon_book_inclusion[work_code]" value="#{@canon_book_inclusion.work_code}" class="materio-form-control" placeholder="Enter work code...">
            </div>

            <div class="materio-form-group">
              <div class="materio-form-label">
                <i class="ri ri-arrow-left-line me-2"></i>
                <span>Include From</span>
              </div>
              <input type="text" name="canon_book_inclusion[include_from]" value="#{@canon_book_inclusion.include_from}" class="materio-form-control" placeholder="Enter include from...">
            </div>

            <div class="materio-form-group">
              <div class="materio-form-label">
                <i class="ri ri-arrow-right-line me-2"></i>
                <span>Include To</span>
              </div>
              <input type="text" name="canon_book_inclusion[include_to]" value="#{@canon_book_inclusion.include_to}" class="materio-form-control" placeholder="Enter include to...">
            </div>

            <div class="materio-form-group">
              <div class="materio-form-label">
                <i class="ri ri-file-text-line me-2"></i>
                <span>Notes</span>
              </div>
              <textarea name="canon_book_inclusion[notes]" class="materio-form-control" placeholder="Enter notes..." rows="4">#{@canon_book_inclusion.notes}</textarea>
            </div>

            <!-- Actions Section -->
            <div class="mt-4 pt-4 border-top">
              <div class="d-flex justify-content-end gap-3">
                <button type="submit" class="materio-btn-primary">
                  <i class="ri ri-save-line me-2"></i>
                  Update Inclusion
                </button>
                <a href="#{admin_canon_book_inclusion_path("#{@canon_book_inclusion.canon_id}-#{@canon_book_inclusion.work_code}")}" class="materio-btn-secondary">
                  <i class="ri ri-close-line me-2"></i>
                  Cancel
                </a>
              </div>
            </div>
          </div>
        </form>
      HTML
    end

    def show_page_content
      <<~HTML

        <div class="page-header mb-4">
          <div class="d-flex justify-content-between align-items-center">
            <div>
              <h1 class="mb-2 text-primary">Canon Book Inclusion Details</h1>
              <p class="text-muted mb-0">View detailed information about this canon book inclusion</p>
            </div>
            <div class="d-flex gap-2">
              <a href="#{edit_admin_canon_book_inclusion_path(@canon_book_inclusion.canon_id, @canon_book_inclusion.work_code)}" class="btn btn-primary">Edit Inclusion</a>
              <a href="#{admin_canon_book_inclusions_path}" class="btn btn-outline-secondary">Back to Canon Inclusions</a>
            </div>
          </div>
        </div>

        <div class="row g-4">
          <!-- Inclusion Profile Card -->
          <div class="col-lg-4">
            <div class="card h-100">
              <div class="card-body text-center p-4">
                <div class="materio-avatar">
                  <i class="ri ri-book-line text-primary" style="font-size: 2rem;"></i>
                </div>
                <h3 class="mb-2">#{@canon_book_inclusion.work_code}</h3>
                <div class="d-flex justify-content-center gap-2 mb-3">
                  <span class="badge bg-primary fs-6">
                    <a href="#{admin_canon_path(@canon_book_inclusion.canon)}" class="text-white text-decoration-none">#{@canon_book_inclusion.canon.name}</a>
                  </span>
                </div>
                #{@canon_book_inclusion.notes.present? ? "<p class='text-muted mb-0'>#{@canon_book_inclusion.notes}</p>" : ""}
              </div>
            </div>
          </div>

          <!-- Inclusion Information Card -->
          <div class="col-lg-8">
            <div class="card h-100">
              <div class="card-header bg-primary text-white">
                <h5 class="mb-0">
                  <i class="ri ri-information-line me-2"></i>
                  Inclusion Information
                </h5>
              </div>
              <div class="card-body">
                <div class="row g-3">
                  <div class="col-md-6">
                    <div class="d-flex align-items-center p-3 bg-light rounded">
                      <i class="ri ri-book-line text-primary me-3 fs-4"></i>
                      <div>
                        <div class="text-muted small">Canon</div>
                        <div class="fw-semibold">
                          <a href="#{admin_canon_path(@canon_book_inclusion.canon)}" class="text-decoration-none">#{@canon_book_inclusion.canon.name}</a>
                        </div>
                      </div>
                    </div>
                  </div>
                  <div class="col-md-6">
                    <div class="d-flex align-items-center p-3 bg-light rounded">
                      <i class="ri ri-code-line text-primary me-3 fs-4"></i>
                      <div>
                        <div class="text-muted small">Work Code</div>
                        <div class="fw-semibold">#{@canon_book_inclusion.work_code}</div>
                      </div>
                    </div>
                  </div>
                  <div class="col-md-6">
                    <div class="d-flex align-items-center p-3 bg-light rounded">
                      <i class="ri ri-arrow-left-line text-primary me-3 fs-4"></i>
                      <div>
                        <div class="text-muted small">Include From</div>
                        <div class="fw-semibold">#{@canon_book_inclusion.include_from || "Not specified"}</div>
                      </div>
                    </div>
                  </div>
                  <div class="col-md-6">
                    <div class="d-flex align-items-center p-3 bg-light rounded">
                      <i class="ri ri-arrow-right-line text-primary me-3 fs-4"></i>
                      <div>
                        <div class="text-muted small">Include To</div>
                        <div class="fw-semibold">#{@canon_book_inclusion.include_to || "Not specified"}</div>
                      </div>
                    </div>
                  </div>
                  <div class="col-md-6">
                    <div class="materio-metric-card">
                      <div class="materio-metric-value">#{@canon_book_inclusion.canon_id}</div>
                      <div class="materio-metric-label">Canon ID</div>
                    </div>
                  </div>
                  <div class="col-md-6">
                    <div class="d-flex align-items-center p-3 bg-light rounded">
                      <i class="ri ri-calendar-line text-primary me-3 fs-4"></i>
                      <div>
                        <div class="text-muted small">Created</div>
                        <div class="fw-semibold">#{@canon_book_inclusion.created_at.strftime("%B %d, %Y")}</div>
                      </div>
                    </div>
                  </div>
                  #{@canon_book_inclusion.notes.present? ? "
                  <div class='col-12'>
                    <div class='p-3 bg-light rounded'>
                      <div class='text-muted small mb-2'>
                        <i class='ri ri-file-text-line me-1'></i>
                        Notes
                      </div>
                      <div class='fw-semibold'>#{@canon_book_inclusion.notes}</div>
                    </div>
                  </div>
                  " : ""}
                </div>
              </div>
            </div>
          </div>
        </div>
      HTML
    end
  end

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  index do
    div class: "page-header mb-4" do
      h1 "Canon Book Inclusions", class: "mb-2"
      para "Manage book inclusions for different canons", class: "text-muted"
    end

    # Add filters section
    div class: "card mb-4" do
      div class: "card-body" do
        h5 "Filters", class: "card-title mb-3"
        div class: "row g-3" do
          div class: "col-md-3" do
            label "Canon", class: "form-label"
            select name: "q[canon_id_eq]", class: "form-select" do
              option "All Canons", value: ""
              Canon.all.each do |canon|
                option canon.name, value: canon.id, selected: params.dig(:q, :canon_id_eq) == canon.id.to_s
              end
            end
          end
          div class: "col-md-3" do
            label "Work Code", class: "form-label"
            input type: "text", name: "q[work_code_cont]", placeholder: "Search work code...", class: "form-control", value: params.dig(:q, :work_code_cont)
          end
          div class: "col-md-3" do
            label "Include From", class: "form-label"
            input type: "text", name: "q[include_from_cont]", placeholder: "Search include from...", class: "form-control", value: params.dig(:q, :include_from_cont)
          end
          div class: "col-md-3" do
            label "Include To", class: "form-label"
            input type: "text", name: "q[include_to_cont]", placeholder: "Search include to...", class: "form-control", value: params.dig(:q, :include_to_cont)
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterInclusions()" do
            "Filter"
          end
          a href: admin_canon_book_inclusions_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterInclusions() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_canon_book_inclusions_path}';

          var canon = document.querySelector('select[name=\"q[canon_id_eq]\"]').value;
          var workCode = document.querySelector('input[name=\"q[work_code_cont]\"]').value;
          var includeFrom = document.querySelector('input[name=\"q[include_from_cont]\"]').value;
          var includeTo = document.querySelector('input[name=\"q[include_to_cont]\"]').value;

          if (canon && canon !== 'All Canons') {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[canon_id_eq]';
            input.value = canon;
            form.appendChild(input);
          }

          if (workCode) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[work_code_cont]';
            input.value = workCode;
            form.appendChild(input);
          }

          if (includeFrom) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[include_from_cont]';
            input.value = includeFrom;
            form.appendChild(input);
          }

          if (includeTo) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[include_to_cont]';
            input.value = includeTo;
            form.appendChild(input);
          }

          document.body.appendChild(form);
          form.submit();
        }
      ")
    end

    div class: "table-responsive" do
      table class: "table table-striped" do
        thead do
          tr do
            th "CANON", class: "fw-semibold"
            th "WORK CODE", class: "fw-semibold"
            th "INCLUDE FROM", class: "fw-semibold"
            th "INCLUDE TO", class: "fw-semibold"
            th "NOTES", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          canon_book_inclusions.each do |inclusion|
            tr do
              # CANON column
              td do
                div class: "d-flex align-items-center" do
                  div class: "me-2" do
                    i class: "ri ri-book-line text-primary"
                  end
                  div do
                    div class: "fw-semibold" do
                      link_to inclusion.canon.name, admin_canon_path(inclusion.canon), class: "text-decoration-none"
                    end
                    div class: "text-muted small" do
                      inclusion.canon.code
                    end
                  end
                end
              end

              # WORK CODE column
              td do
                span class: "text-body fw-semibold" do
                  inclusion.work_code
                end
              end

              # INCLUDE FROM column
              td do
                span class: "text-body" do
                  inclusion.include_from || "N/A"
                end
              end

              # INCLUDE TO column
              td do
                span class: "text-body" do
                  inclusion.include_to || "N/A"
                end
              end

              # NOTES column
              td do
                span class: "text-body" do
                  inclusion.notes.present? ? truncate(inclusion.notes, length: 30) : "N/A"
    end
  end

              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_canon_book_inclusion_path("#{inclusion.canon_id}-#{inclusion.work_code}")}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_canon_book_inclusion_path("#{inclusion.canon_id}-#{inclusion.work_code}")}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_canon_book_inclusion_path("#{inclusion.canon_id}-#{inclusion.work_code}")}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
                </div>")
              end
            end
          end
        end
      end
    end
  end

  filter :canon
  filter :work_code
  filter :include_from
  filter :include_to
  filter :created_at



end
