ActiveAdmin.register CanonWorkPreference do
  permit_params :canon_id, :work_code, :foundation_code, :numbering_system_code, :notes

  # Custom page title
  menu label: "Canon Preferences", priority: 11

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
      @canon_work_preference = find_resource
      raise ActiveRecord::RecordNotFound unless @canon_work_preference

      # Set the resource for Active Admin
      @resource = @canon_work_preference

      # Render our custom show content directly
      render inline: show_page_content, layout: "active_admin_custom"
    end

    # Override the edit method to handle composite primary keys properly
    def edit
      @canon_work_preference = find_resource
      raise ActiveRecord::RecordNotFound unless @canon_work_preference

      # Set the resource for Active Admin
      @resource = @canon_work_preference

      # Render our custom edit content directly
      render inline: edit_page_content, layout: "active_admin_custom"
    end

    # Override the update method to handle composite primary keys properly
    def update
      # Parse the composite primary key from params[:id]
      id_part = params[:id]

      if id_part && id_part.include?('-')
        canon_id, work_code = id_part.split('-', 2)
        @canon_work_preference = resource_class.find_by(canon_id: canon_id.to_i, work_code: work_code)
      elsif id_part && id_part.include?('.')
        canon_id, work_code = id_part.split('.', 2)
        @canon_work_preference = resource_class.find_by(canon_id: canon_id.to_i, work_code: work_code)
      else
        raise ActiveRecord::RecordNotFound, "Invalid composite key format"
      end

      raise ActiveRecord::RecordNotFound unless @canon_work_preference

      # Update the record using raw SQL to avoid composite primary key issues
      params = canon_work_preference_params
      update_sql = <<~SQL
        UPDATE canon_work_preferences
        SET foundation_code = $1, numbering_system_code = $2, notes = $3, updated_at = $4
        WHERE canon_id = $5 AND work_code = $6
      SQL

      ActiveRecord::Base.connection.exec_query(
        update_sql,
        'SQL',
        [
          params[:foundation_code],
          params[:numbering_system_code],
          params[:notes],
          Time.current,
          canon_id.to_i,
          work_code
        ]
      )

      # Check if the record still exists (update was successful)
      updated_record = resource_class.find_by(canon_id: canon_id.to_i, work_code: work_code)
      if updated_record
        redirect_to admin_canon_work_preference_path("#{canon_id}-#{work_code}"), notice: 'Canon work preference was successfully updated.'
      else
        @canon_work_preference = resource_class.find_by(canon_id: canon_id.to_i, work_code: work_code)
        @resource = @canon_work_preference
        render inline: edit_page_content, layout: "active_admin_custom"
      end
    end

    # Override the destroy method to handle composite primary keys properly
    def destroy
      # Parse the composite primary key from params[:id]
      id_part = params[:id]

      if id_part && id_part.include?('-')
        canon_id, work_code = id_part.split('-', 2)
        @canon_work_preference = resource_class.find_by(canon_id: canon_id.to_i, work_code: work_code)
      elsif id_part && id_part.include?('.')
        canon_id, work_code = id_part.split('.', 2)
        @canon_work_preference = resource_class.find_by(canon_id: canon_id.to_i, work_code: work_code)
      else
        raise ActiveRecord::RecordNotFound, "Invalid composite key format"
      end

      raise ActiveRecord::RecordNotFound unless @canon_work_preference

      # Use raw SQL to delete the record with composite primary key
      delete_sql = <<~SQL
        DELETE FROM canon_work_preferences
        WHERE canon_id = $1 AND work_code = $2
      SQL

      ActiveRecord::Base.connection.exec_query(
        delete_sql,
        'SQL',
        [canon_id.to_i, work_code]
      )

      redirect_to admin_canon_work_preferences_path, notice: 'Canon work preference was successfully deleted.'
    end

    private

    def canon_work_preference_params
      params.require(:canon_work_preference).permit(:canon_id, :work_code, :foundation_code, :numbering_system_code, :notes)
    end

    def edit_page_content
      <<~HTML
        <style>
          .materio-form-group {
            margin-bottom: 1.5rem;
          }
          .materio-form-label {
            font-weight: 600;
            color: #697a8d;
            margin-bottom: 0.5rem;
            font-size: 0.875rem;
            display: flex;
            align-items: center;
          }
          .materio-form-control {
            border: 1px solid #e7eaf3;
            border-radius: 0.5rem;
            padding: 0.75rem 1rem;
            font-size: 0.875rem;
            transition: all 0.3s ease;
            background-color: #fff;
          }
          .materio-form-control:focus {
            border-color: #696cff;
            box-shadow: 0 0 0 0.2rem rgba(105, 108, 255, 0.25);
            outline: none;
          }
          .materio-btn-primary {
            background: linear-gradient(135deg, #696cff 0%, #5a5fcf 100%);
            border: none;
            border-radius: 0.5rem;
            color: white;
            font-weight: 600;
            font-size: 0.875rem;
            padding: 0.75rem 2rem;
            transition: all 0.3s ease;
            box-shadow: 0 0.125rem 0.25rem rgba(105, 108, 255, 0.3);
          }
          .materio-btn-primary:hover {
            background: linear-gradient(135deg, #5a5fcf 0%, #4a4fb8 100%);
            transform: translateY(-1px);
            box-shadow: 0 0.25rem 0.5rem rgba(105, 108, 255, 0.4);
            color: white;
          }
          .materio-btn-secondary {
            background: white;
            border: 1px solid #e7eaf3;
            border-radius: 0.5rem;
            color: #697a8d;
            font-weight: 600;
            font-size: 0.875rem;
            padding: 0.75rem 2rem;
            transition: all 0.3s ease;
          }
          .materio-btn-secondary:hover {
            background: #f8f9fa;
            border-color: #d9dee3;
            color: #2b2c40;
            transform: translateY(-1px);
            box-shadow: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.1);
          }
        </style>

        <div class="page-header mb-4">
          <div class="d-flex justify-content-between align-items-center">
            <div>
              <h1 class="mb-2 text-primary">Edit Canon Work Preference</h1>
              <p class="text-muted mb-0">Update canon work preference settings</p>
            </div>
            <div>
              <a href="#{admin_canon_work_preferences_path}" class="btn btn-outline-secondary">Back to Canon Preferences</a>
            </div>
          </div>
        </div>

        <form action="#{admin_canon_work_preference_path("#{@canon_work_preference.canon_id}-#{@canon_work_preference.work_code}")}" method="post" class="card">
          <input type="hidden" name="_method" value="patch">
          <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">

          <div class="card-header bg-primary text-white">
            <h5 class="mb-0">
              <i class="ri ri-edit-line me-2"></i>
              Preference Information
            </h5>
          </div>
          <div class="card-body p-4">
            <div class="materio-form-group">
              <div class="materio-form-label">
                <i class="ri ri-book-line me-2"></i>
                <span>Canon</span>
              </div>
              <select name="canon_work_preference[canon_id]" class="materio-form-control">
                #{Canon.all.map { |c| "<option value='#{c.id}' #{'selected' if c.id == @canon_work_preference.canon_id}>#{c.name}</option>" }.join}
              </select>
            </div>

            <div class="materio-form-group">
              <div class="materio-form-label">
                <i class="ri ri-code-line me-2"></i>
                <span>Work Code</span>
              </div>
              <input type="text" name="canon_work_preference[work_code]" value="#{@canon_work_preference.work_code}" class="materio-form-control" placeholder="Enter work code...">
            </div>

            <div class="materio-form-group">
              <div class="materio-form-label">
                <i class="ri ri-building-line me-2"></i>
                <span>Foundation Code</span>
              </div>
              <input type="text" name="canon_work_preference[foundation_code]" value="#{@canon_work_preference.foundation_code}" class="materio-form-control" placeholder="Enter foundation code...">
            </div>

            <div class="materio-form-group">
              <div class="materio-form-label">
                <i class="ri ri-list-numbers me-2"></i>
                <span>Numbering System Code</span>
              </div>
              <input type="text" name="canon_work_preference[numbering_system_code]" value="#{@canon_work_preference.numbering_system_code}" class="materio-form-control" placeholder="Enter numbering system code...">
            </div>

            <div class="materio-form-group">
              <div class="materio-form-label">
                <i class="ri ri-file-text-line me-2"></i>
                <span>Notes</span>
              </div>
              <textarea name="canon_work_preference[notes]" class="materio-form-control" placeholder="Enter notes..." rows="4">#{@canon_work_preference.notes}</textarea>
            </div>

            <!-- Actions Section -->
            <div class="mt-4 pt-4 border-top">
              <div class="d-flex justify-content-end gap-3">
                <button type="submit" class="materio-btn-primary">
                  <i class="ri ri-save-line me-2"></i>
                  Update Preference
                </button>
                <a href="#{admin_canon_work_preference_path("#{@canon_work_preference.canon_id}-#{@canon_work_preference.work_code}")}" class="materio-btn-secondary">
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
        <style>
          .materio-avatar {
            width: 5rem;
            height: 5rem;
            border-radius: 50%;
            border: 3px solid #696cff;
            margin: 0 auto 1.5rem;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          .materio-metric-card {
            background: linear-gradient(135deg, #696cff 0%, #5a5fcf 100%);
            border-radius: 1rem;
            padding: 1.5rem;
            color: white;
            text-align: center;
            box-shadow: 0 0.5rem 1rem rgba(105, 108, 255, 0.3);
          }
          .materio-metric-value {
            font-size: 2rem;
            font-weight: 700;
            margin-bottom: 0.5rem;
          }
          .materio-metric-label {
            font-size: 0.875rem;
            opacity: 0.9;
          }
        </style>

        <div class="page-header mb-4">
          <div class="d-flex justify-content-between align-items-center">
            <div>
              <h1 class="mb-2 text-primary">Canon Work Preference Details</h1>
              <p class="text-muted mb-0">View detailed information about this canon work preference</p>
            </div>
            <div class="d-flex gap-2">
              <a href="#{edit_admin_canon_work_preference_path("#{@canon_work_preference.canon_id}-#{@canon_work_preference.work_code}")}" class="btn btn-primary">Edit Preference</a>
              <a href="#{admin_canon_work_preferences_path}" class="btn btn-outline-secondary">Back to Canon Preferences</a>
            </div>
          </div>
        </div>

        <div class="row g-4">
          <!-- Preference Profile Card -->
          <div class="col-lg-4">
            <div class="card h-100">
              <div class="card-body text-center p-4">
                <div class="materio-avatar">
                  <i class="ri ri-settings-line text-primary" style="font-size: 2rem;"></i>
                </div>
                <h3 class="mb-2">#{@canon_work_preference.work_code}</h3>
                <div class="d-flex justify-content-center gap-2 mb-3">
                  <span class="badge bg-primary fs-6">
                    <a href="#{admin_canon_path(@canon_work_preference.canon)}" class="text-white text-decoration-none">#{@canon_work_preference.canon.name}</a>
                  </span>
                </div>
                #{@canon_work_preference.notes.present? ? "<p class='text-muted mb-0'>#{@canon_work_preference.notes}</p>" : ""}
              </div>
            </div>
          </div>

          <!-- Preference Information Card -->
          <div class="col-lg-8">
            <div class="card h-100">
              <div class="card-header bg-primary text-white">
                <h5 class="mb-0">
                  <i class="ri ri-information-line me-2"></i>
                  Preference Information
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
                          <a href="#{admin_canon_path(@canon_work_preference.canon)}" class="text-decoration-none">#{@canon_work_preference.canon.name}</a>
                        </div>
                      </div>
                    </div>
                  </div>
                  <div class="col-md-6">
                    <div class="d-flex align-items-center p-3 bg-light rounded">
                      <i class="ri ri-code-line text-primary me-3 fs-4"></i>
                      <div>
                        <div class="text-muted small">Work Code</div>
                        <div class="fw-semibold">#{@canon_work_preference.work_code}</div>
                      </div>
                    </div>
                  </div>
                  <div class="col-md-6">
                    <div class="d-flex align-items-center p-3 bg-light rounded">
                      <i class="ri ri-building-line text-primary me-3 fs-4"></i>
                      <div>
                        <div class="text-muted small">Foundation Code</div>
                        <div class="fw-semibold">#{@canon_work_preference.foundation_code || "Not specified"}</div>
                      </div>
                    </div>
                  </div>
                  <div class="col-md-6">
                    <div class="d-flex align-items-center p-3 bg-light rounded">
                      <i class="ri ri-list-numbers text-primary me-3 fs-4"></i>
                      <div>
                        <div class="text-muted small">Numbering System Code</div>
                        <div class="fw-semibold">#{@canon_work_preference.numbering_system_code || "Not specified"}</div>
                      </div>
                    </div>
                  </div>
                  <div class="col-md-6">
                    <div class="materio-metric-card">
                      <div class="materio-metric-value">#{@canon_work_preference.canon_id}</div>
                      <div class="materio-metric-label">Canon ID</div>
                    </div>
                  </div>
                  <div class="col-md-6">
                    <div class="d-flex align-items-center p-3 bg-light rounded">
                      <i class="ri ri-calendar-line text-primary me-3 fs-4"></i>
                      <div>
                        <div class="text-muted small">Created</div>
                        <div class="fw-semibold">#{@canon_work_preference.created_at.strftime("%B %d, %Y")}</div>
                      </div>
                    </div>
                  </div>
                  #{@canon_work_preference.notes.present? ? "
                  <div class='col-12'>
                    <div class='p-3 bg-light rounded'>
                      <div class='text-muted small mb-2'>
                        <i class='ri ri-file-text-line me-1'></i>
                        Notes
                      </div>
                      <div class='fw-semibold'>#{@canon_work_preference.notes}</div>
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
      h1 "Canon Work Preferences", class: "mb-2"
      para "Manage work preferences for different canons", class: "text-muted"
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
            label "Foundation Code", class: "form-label"
            input type: "text", name: "q[foundation_code_cont]", placeholder: "Search foundation...", class: "form-control", value: params.dig(:q, :foundation_code_cont)
          end
          div class: "col-md-3" do
            label "Numbering System", class: "form-label"
            input type: "text", name: "q[numbering_system_code_cont]", placeholder: "Search numbering...", class: "form-control", value: params.dig(:q, :numbering_system_code_cont)
          end
        end
        div class: "mt-3" do
          button type: "submit", class: "btn btn-primary me-2", onclick: "filterPreferences()" do
            "Filter"
          end
          a href: admin_canon_work_preferences_path, class: "btn btn-outline-secondary" do
            "Clear Filters"
          end
        end
      end
    end

    # Add JavaScript for form submission
    script do
      raw("
        function filterPreferences() {
          var form = document.createElement('form');
          form.method = 'GET';
          form.action = '#{admin_canon_work_preferences_path}';

          var canon = document.querySelector('select[name=\"q[canon_id_eq]\"]').value;
          var workCode = document.querySelector('input[name=\"q[work_code_cont]\"]').value;
          var foundationCode = document.querySelector('input[name=\"q[foundation_code_cont]\"]').value;
          var numberingSystem = document.querySelector('input[name=\"q[numbering_system_code_cont]\"]').value;

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

          if (foundationCode) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[foundation_code_cont]';
            input.value = foundationCode;
            form.appendChild(input);
          }

          if (numberingSystem) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'q[numbering_system_code_cont]';
            input.value = numberingSystem;
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
            th "FOUNDATION", class: "fw-semibold"
            th "NUMBERING SYSTEM", class: "fw-semibold"
            th "NOTES", class: "fw-semibold"
            th "ACTIONS", class: "fw-semibold"
          end
        end
        tbody do
          canon_work_preferences.each do |pref|
            tr do
              # CANON column
              td do
                div class: "d-flex align-items-center" do
                  div class: "me-2" do
                    i class: "ri ri-settings-line text-primary"
                  end
                  div do
                    div class: "fw-semibold" do
                      link_to pref.canon.name, admin_canon_path(pref.canon), class: "text-decoration-none"
                    end
                    div class: "text-muted small" do
                      pref.canon.code
                    end
                  end
                end
              end

              # WORK CODE column
              td do
                span class: "text-body fw-semibold" do
                  pref.work_code
                end
              end

              # FOUNDATION column
              td do
                span class: "text-body" do
                  pref.foundation_code || "N/A"
                end
              end

              # NUMBERING SYSTEM column
              td do
                span class: "text-body" do
                  pref.numbering_system_code || "N/A"
                end
              end

              # NOTES column
              td do
                span class: "text-body" do
                  pref.notes.present? ? truncate(pref.notes, length: 30) : "N/A"
    end
  end

              # ACTIONS column
              td do
                raw("<div class='d-flex gap-2'>
                  <a href='#{admin_canon_work_preference_path("#{pref.canon_id}-#{pref.work_code}")}' class='btn btn-sm btn-outline-primary'>View</a>
                  <a href='#{edit_admin_canon_work_preference_path("#{pref.canon_id}-#{pref.work_code}")}' class='btn btn-sm btn-outline-secondary'>Edit</a>
                  <a href='#{admin_canon_work_preference_path("#{pref.canon_id}-#{pref.work_code}")}' class='btn btn-sm btn-outline-danger' data-method='delete' data-confirm='Are you sure?'>Delete</a>
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
  filter :foundation_code
  filter :numbering_system_code
  filter :created_at


end
