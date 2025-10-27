ActiveAdmin.register_page "Dashboard" do
  # Custom page title
  menu label: "Dashboard", priority: 1

  # Force custom layout
  controller do
    layout "active_admin_custom"
  end

  content do
    div class: "dashboard-content" do
      h1 "Dashboard", class: "mb-4"
      para "Welcome to VeriFaith Admin Panel", class: "text-muted"

      # Top Row - Key Metrics Cards
      div class: "row mt-4" do
        div class: "col-md-3" do
          div class: "card" do
            div class: "card-body" do
              div class: "d-flex justify-content-between align-items-start" do
                div do
                  h6 "Total Claims", class: "card-title text-muted mb-1"
                  h3 Claim.count, class: "text-primary mb-0"
                  small "All submitted claims", class: "text-muted"
                end
                div class: "avatar avatar-sm bg-primary rounded-circle d-flex align-items-center justify-content-center" do
                  i class: "ri ri-file-text-line text-white"
                end
              end
            end
          end
        end

        div class: "col-md-3" do
          div class: "card" do
            div class: "card-body" do
              div class: "d-flex justify-content-between align-items-start" do
                div do
                  h6 "Total Users", class: "card-title text-muted mb-1"
                  h3 User.count, class: "text-success mb-0"
                  small "Registered users", class: "text-muted"
                end
                div class: "avatar avatar-sm bg-success rounded-circle d-flex align-items-center justify-content-center" do
                  i class: "ri ri-user-line text-white"
                end
              end
            end
          end
        end

        div class: "col-md-3" do
          div class: "card" do
            div class: "card-body" do
              div class: "d-flex justify-content-between align-items-start" do
                div do
                  h6 "Name Mappings", class: "card-title text-muted mb-1"
                  h3 NameMapping.count, class: "text-info mb-0"
                  small "Cross-tradition mappings", class: "text-muted"
                end
                div class: "avatar avatar-sm bg-info rounded-circle d-flex align-items-center justify-content-center" do
                  i class: "ri ri-links-line text-white"
                end
              end
            end
          end
        end

        div class: "col-md-3" do
          div class: "card" do
            div class: "card-body" do
              div class: "d-flex justify-content-between align-items-start" do
                div do
                  h6 "Active Users", class: "card-title text-muted mb-1"
                  h3 User.where(confirmed_at: 1.week.ago..).count, class: "text-warning mb-0"
                  small "Active this week", class: "text-muted"
                end
                div class: "avatar avatar-sm bg-warning rounded-circle d-flex align-items-center justify-content-center" do
                  i class: "ri ri-user-heart-line text-white"
                end
              end
            end
          end
        end
      end

      # Second Row - New Tables Metrics
      div class: "row mt-4" do
        div class: "col-md-3" do
          div class: "card" do
            div class: "card-body" do
              div class: "d-flex justify-content-between align-items-start" do
                div do
                  h6 "Languages", class: "card-title text-muted mb-1"
                  h3 Language.count, class: "text-primary mb-0"
                  small "Available languages", class: "text-muted"
                end
                div class: "avatar avatar-sm bg-primary rounded-circle d-flex align-items-center justify-content-center" do
                  i class: "ri ri-translate text-white"
                end
              end
            end
          end
        end

        div class: "col-md-3" do
          div class: "card" do
            div class: "card-body" do
              div class: "d-flex justify-content-between align-items-start" do
                div do
                  h6 "Sources", class: "card-title text-muted mb-1"
                  h3 Source.count, class: "text-success mb-0"
                  small "Textual sources", class: "text-muted"
                end
                div class: "avatar avatar-sm bg-success rounded-circle d-flex align-items-center justify-content-center" do
                  i class: "ri ri-book-line text-white"
                end
              end
            end
          end
        end

        div class: "col-md-3" do
          div class: "card" do
            div class: "card-body" do
              div class: "d-flex justify-content-between align-items-start" do
                div do
                  h6 "Books", class: "card-title text-muted mb-1"
                  h3 Book.count, class: "text-warning mb-0"
                  small "Biblical books", class: "text-muted"
                end
                div class: "avatar avatar-sm bg-warning rounded-circle d-flex align-items-center justify-content-center" do
                  i class: "ri ri-book-open-line text-white"
                end
              end
            end
          end
        end

        div class: "col-md-3" do
          div class: "card" do
            div class: "card-body" do
              div class: "d-flex justify-content-between align-items-start" do
                div do
                  h6 "Canons", class: "card-title text-muted mb-1"
                  h3 Canon.count, class: "text-danger mb-0"
                  small "Religious canons", class: "text-muted"
                end
                div class: "avatar avatar-sm bg-danger rounded-circle d-flex align-items-center justify-content-center" do
                  i class: "ri ri-list-check text-white"
                end
              end
            end
          end
        end
      end

      # Third Row - Canon Books Metric
      div class: "row mt-4" do
        div class: "col-md-3" do
          div class: "card" do
            div class: "card-body" do
              div class: "d-flex justify-content-between align-items-start" do
                div do
                  h6 "Canon Books", class: "card-title text-muted mb-1"
                  h3 CanonBook.count, class: "text-info mb-0"
                  small "Canon-book relationships", class: "text-muted"
                end
                div class: "avatar avatar-sm bg-info rounded-circle d-flex align-items-center justify-content-center" do
                  i class: "ri ri-list-check-2 text-white"
                end
              end
            end
          end
        end

        div class: "col-md-9" do
          div class: "card" do
            div class: "card-body" do
              h5 "Quick Stats", class: "card-title"
              div class: "row" do
                div class: "col-md-4" do
                  div class: "text-center" do
                    h4 Language.count, class: "text-primary mb-1"
                    small "Languages", class: "text-muted"
                  end
                end
                div class: "col-md-4" do
                  div class: "text-center" do
                    h4 Source.count, class: "text-success mb-1"
                    small "Sources", class: "text-muted"
                  end
                end
                div class: "col-md-4" do
                  div class: "text-center" do
                    h4 Book.count, class: "text-warning mb-1"
                    small "Books", class: "text-muted"
                  end
                end
              end
            end
          end
        end
      end

      # Fourth Row - Text Unit Types and Text Contents Metrics
      div class: "row mt-4" do
        div class: "col-md-3" do
          div class: "card" do
            div class: "card-body" do
              div class: "d-flex justify-content-between align-items-start" do
                div do
                  h6 "Text Unit Types", class: "card-title text-muted mb-1"
                  h3 TextUnitType.count, class: "text-warning mb-0"
                  small "Available unit types", class: "text-muted"
                end
                div class: "avatar avatar-sm bg-warning rounded-circle d-flex align-items-center justify-content-center" do
                  i class: "ri ri-list-check-3 text-white"
                end
              end
            end
          end
        end

        div class: "col-md-3" do
          div class: "card" do
            div class: "card-body" do
              div class: "d-flex justify-content-between align-items-start" do
                div do
                  h6 "Text Contents", class: "card-title text-muted mb-1"
                  h3 TextContent.count, class: "text-success mb-0"
                  small "Text content entries", class: "text-muted"
                end
                div class: "avatar avatar-sm bg-success rounded-circle d-flex align-items-center justify-content-center" do
                  i class: "ri ri-file-text-line text-white"
                end
              end
            end
          end
        end

        div class: "col-md-6" do
          div class: "card" do
            div class: "card-body" do
              h5 "Text Content Stats", class: "card-title"
              div class: "row" do
                div class: "col-md-6" do
                  div class: "text-center" do
                    h4 TextUnitType.count, class: "text-warning mb-1"
                    small "Unit Types", class: "text-muted"
                  end
                end
                div class: "col-md-6" do
                  div class: "text-center" do
                    h4 TextContent.count, class: "text-success mb-1"
                    small "Text Contents", class: "text-muted"
                  end
                end
              end
            end
          end
        end
      end

      # Middle Row - Charts
      div class: "row mt-4" do
        div class: "col-md-6" do
          div class: "card" do
            div class: "card-body" do
              h5 "Claims Over Time", class: "card-title"
              div class: "chart-container", style: "height: 300px;" do
                canvas id: "claimsChart"
              end
            end
          end
        end

        div class: "col-md-6" do
          div class: "card" do
            div class: "card-body" do
              h5 "User Registrations", class: "card-title"
              div class: "chart-container", style: "height: 300px;" do
                canvas id: "usersChart"
              end
            end
          end
        end
      end

      # Bottom Row - Additional Charts and Activity
      div class: "row mt-4" do
        div class: "col-md-3" do
          div class: "card" do
            div class: "card-body" do
              h5 "Claims by Status", class: "card-title"
              div class: "chart-container", style: "height: 250px;" do
                canvas id: "claimsByStatusChart"
              end
            end
          end
        end

        div class: "col-md-3" do
          div class: "card" do
            div class: "card-body" do
              h5 "Recent Activity", class: "card-title"
              div class: "activity-timeline" do
                Claim.order(created_at: :desc).limit(5).each do |claim|
                  link_to admin_claim_path(claim), class: "activity-item d-flex align-items-start mb-3 text-decoration-none" do
                    div class: "avatar avatar-sm bg-primary rounded-circle me-3 d-flex align-items-center justify-content-center" do
                      i class: "ri ri-file-text-line text-white"
                    end
                    div class: "flex-grow-1" do
                      div class: "fw-semibold small text-dark" do
                        "New claim submitted"
                      end
                      div class: "text-muted small mb-1" do
                        "by #{claim.user&.email || 'Unknown User'}"
                      end
                      div class: "text-body small mb-1" do
                        truncate(claim.content, length: 60)
                      end
                      div class: "text-muted small" do
                        time_ago_in_words(claim.created_at) + " ago"
                      end
                    end
                  end
                end
              end
            end
          end
        end

        div class: "col-md-3" do
          div class: "card" do
            div class: "card-body" do
              h5 "Top Users", class: "card-title"
              div class: "top-users" do
                User.joins(:claims).group('users.id').order('COUNT(claims.id) DESC').limit(5).each do |user|
                  link_to admin_user_path(user), class: "user-item d-flex align-items-center mb-3 text-decoration-none" do
                    div class: "avatar avatar-sm me-3" do
                      img src: asset_path("avatars/#{(user.id % 20) + 1}.png"),
                          alt: user.full_name || user.email,
                          class: "rounded-circle"
                    end
                    div class: "flex-grow-1" do
                      div class: "fw-semibold small text-dark" do
                        user.full_name || user.email.split('@').first.titleize
                      end
                      div class: "text-muted small" do
                        user.email
                      end
                    end
                    div class: "text-end" do
                      span class: "badge bg-primary" do
                        user.claims.count
                      end
                      div class: "text-muted small" do
                        "claims"
                      end
                    end
                  end
                end
              end
            end
          end
        end

        div class: "col-md-3" do
          div class: "card" do
            div class: "card-body" do
              h5 "Growth Metrics", class: "card-title"
              div class: "growth-metrics" do
                current_month_claims = Claim.where(created_at: 1.month.ago..).count
                previous_month_claims = Claim.where(created_at: 2.months.ago..1.month.ago).count
                claims_growth = previous_month_claims > 0 ? ((current_month_claims.to_f / previous_month_claims) * 100 - 100).round(1) : 0

                current_month_users = User.where(created_at: 1.month.ago..).count
                previous_month_users = User.where(created_at: 2.months.ago..1.month.ago).count
                users_growth = previous_month_users > 0 ? ((current_month_users.to_f / previous_month_users) * 100 - 100).round(1) : 0

                active_users_percentage = User.count > 0 ? ((User.where(confirmed_at: 1.week.ago..).count.to_f / User.count) * 100).round(1) : 0

                div class: "metric-item d-flex justify-content-between align-items-center mb-3" do
                  span "Claims Growth"
                  span class: "badge #{claims_growth >= 0 ? 'bg-success' : 'bg-danger'}" do
                    "#{claims_growth >= 0 ? '+' : ''}#{claims_growth}%"
                  end
                end
                div class: "metric-item d-flex justify-content-between align-items-center mb-3" do
                  span "User Growth"
                  span class: "badge #{users_growth >= 0 ? 'bg-success' : 'bg-danger'}" do
                    "#{users_growth >= 0 ? '+' : ''}#{users_growth}%"
                  end
                end
                div class: "metric-item d-flex justify-content-between align-items-center mb-3" do
                  span "Active Users"
                  span class: "badge bg-info" do
                    "#{active_users_percentage}%"
                  end
                end
              end
            end
          end
        end
      end
    end

    # Chart.js Scripts
    script src: "https://cdn.jsdelivr.net/npm/chart.js"
    script do
      raw("
        // Claims Over Time Chart
        const claimsCtx = document.getElementById('claimsChart').getContext('2d');
        const claimsData = #{Claim.group("DATE_TRUNC('month', created_at)").count.to_json};
        const claimsLabels = Object.keys(claimsData).map(date => new Date(date).toLocaleDateString('en-US', { month: 'short', year: 'numeric' }));
        const claimsValues = Object.values(claimsData);

        new Chart(claimsCtx, {
          type: 'line',
          data: {
            labels: claimsLabels,
            datasets: [{
              label: 'Claims',
              data: claimsValues,
              borderColor: '#696cff',
              backgroundColor: 'rgba(105, 108, 255, 0.1)',
              borderWidth: 2,
              fill: true,
              tension: 0.4
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              legend: {
                display: false
              }
            },
            scales: {
              y: {
                beginAtZero: true,
                grid: {
                  color: 'rgba(0,0,0,0.1)'
                }
              },
              x: {
                grid: {
                  display: false
                }
              }
            }
          }
        });

        // User Registrations Chart
        const usersCtx = document.getElementById('usersChart').getContext('2d');
        const usersData = #{User.group("DATE_TRUNC('month', created_at)").count.to_json};
        const usersLabels = Object.keys(usersData).map(date => new Date(date).toLocaleDateString('en-US', { month: 'short', year: 'numeric' }));
        const usersValues = Object.values(usersData);

        new Chart(usersCtx, {
          type: 'bar',
          data: {
            labels: usersLabels,
            datasets: [{
              label: 'Users',
              data: usersValues,
              backgroundColor: '#71dd37',
              borderColor: '#71dd37',
              borderWidth: 1
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              legend: {
                display: false
              }
            },
            scales: {
              y: {
                beginAtZero: true,
                grid: {
                  color: 'rgba(0,0,0,0.1)'
                }
              },
              x: {
                grid: {
                  display: false
                }
              }
            }
          }
        });

        // Claims by Status Chart
        const statusCtx = document.getElementById('claimsByStatusChart').getContext('2d');
        const statusData = #{Claim.group(:state).count.to_json};
        const statusLabels = Object.keys(statusData).map(status => {
          switch(status) {
            case 'draft': return 'Draft';
            case 'ai_validated': return 'AI Validated';
            case 'verified': return 'Verified';
            default: return status;
          }
        });
        const statusValues = Object.values(statusData);
        const statusColors = ['#ffab00', '#696cff', '#71dd37'];

        new Chart(statusCtx, {
          type: 'doughnut',
          data: {
            labels: statusLabels,
            datasets: [{
              data: statusValues,
              backgroundColor: statusColors,
              borderWidth: 0
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              legend: {
                position: 'bottom',
                labels: {
                  padding: 20,
                  usePointStyle: true
                }
              }
            }
          }
        });
      ")
    end
  end
end