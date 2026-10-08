ActiveAdmin.register DictionaryEntry do
  menu parent: "Data Tables", label: "Dictionary", priority: 11

  # Imported corpus — browse/search only to protect letter-perfect raw_json fidelity.
  actions :index, :show

  config.paginate = true
  config.per_page = 25
  config.max_per_page = 100
  config.sort_order = 'word_asc'
  config.filters = true

  # Prefer index-friendly predicates. Avoid loading raw_json/payload in filters.
  filter :word_start, as: :string, label: "Word starts with"
  filter :word_eq, as: :string, label: "Word exact"
  filter :word_cont, as: :string, label: "Word contains"
  filter :pos, as: :select, collection: -> { DictionaryEntry::POS_OPTIONS }
  filter :lang_code, as: :select, collection: -> { [%w[English en]] }
  filter :etymology_number_eq, as: :string, label: "Etymology #"
  filter :line_number_eq, as: :number, label: "Line number"
  filter :senses_count

  controller do
    layout "active_admin_custom"

    # Thin SELECT for index; full row (incl. payload) only on show.
    def scoped_collection
      if action_name == 'index'
        end_of_association_chain.for_index
      else
        end_of_association_chain
      end
    end

    # ActiveAdmin/Kaminari call total_count for pagination. On an unfiltered
    # 1.5M-row table that COUNT(*) is expensive; use planner estimate instead.
    # When filters are present, count exactly with COUNT(*) (for_index SELECT
    # would otherwise make ActiveRecord emit COUNT(col1, col2, ...) which fails).
    #
    # pg_class.reltuples can slightly overshoot the real row count, so "Last"
    # may land past the data and look empty — clamp to the real last page then.
    def apply_pagination(chain)
      return chain if params["format"] == "csv"
      return chain if chain.respond_to?(:total_pages)

      # ~84k words repeat, so ORDER BY word alone is non-deterministic and
      # OFFSET pages can repeat/skip rows. id breaks ties and matches the
      # (word, id) index.
      chain = chain.order(DictionaryEntry.arel_table[:id].asc)

      page = params[Kaminari.config.param_name]
      per = per_page
      page_i = [(page.presence || 1).to_i, 1].max
      used_estimate = use_estimated_total_count?

      total = if used_estimate
                [DictionaryEntry.estimated_count, 0].max
              else
                exact_total(chain)
              end

      page_chain = params.dig(:q, :word_start).present? ? filter_before_sort(chain) : chain
      offset = (page_i - 1) * per
      rows = page_chain.offset(offset).limit(per).to_a

      if rows.empty? && page_i > 1
        total = exact_total(chain) if used_estimate
        max_page = [(total.to_f / per).ceil, 1].max
        page_i = [page_i, max_page].min
        offset = (page_i - 1) * per
        rows = page_chain.offset(offset).limit(per).to_a
      end

      # Pass limit/offset so Kaminari treats +rows+ as the already-fetched page
      # (total_count >> rows.size) and reports the correct current_page.
      Kaminari.paginate_array(
        rows,
        total_count: [total, offset + rows.size].max,
        limit: per,
        offset: offset
      )
    end

    private

    def exact_total(chain)
      chain.except(:select, :order, :offset, :limit).count(:all)
    end

    # With a prefix filter, Postgres misjudges where matches sit in the
    # (word, id) index and walks it from "A" (6s+ for a one-letter prefix).
    # OFFSET 0 stops the planner flattening the subquery, so it fetches matches
    # via the lower(word) prefix index first, then sorts that smaller set.
    def filter_before_sort(chain)
      filtered = chain.except(:order, :offset, :limit).offset(0)
      DictionaryEntry.unscoped
                     .from(filtered, DictionaryEntry.table_name)
                     .select(chain.select_values)
                     .order(chain.order_values)
    end

    def use_estimated_total_count?
      q = params[:q]
      return true if q.blank?

      hash = q.respond_to?(:to_unsafe_h) ? q.to_unsafe_h : q.to_h
      meaningful = hash.any? do |key, value|
        next false if value.blank?
        next false if key.to_s == 'senses_count_gteq' && value.to_s == '0'
        true
      end
      !meaningful
    end
  end

  index download_links: false do
    div class: "page-header mb-4" do
      div class: "d-flex justify-content-between align-items-start" do
        div do
          h1 "Dictionary Entries", class: "mb-2"
          para "Wiktionary corpus (#{number_with_delimiter(DictionaryEntry.estimated_count)} estimated entries). Prefer prefix search for speed.", class: "text-muted mb-0"
        end
      end
    end

    # Quick filters — prefix-first so Postgres can use text_pattern_ops / btree indexes
    div class: "card mb-4" do
      div class: "card-header bg-light" do
        h5 "Quick Search", class: "mb-0"
      end
      div class: "card-body" do
        div class: "row g-3" do
          div class: "col-md-3" do
            label "Word starts with (fast)", class: "form-label"
            input type: "text", class: "form-control", id: "dict-word-start",
                  placeholder: "e.g. dict",
                  value: params.dig(:q, :word_start)
          end
          div class: "col-md-3" do
            label "Word exact", class: "form-label"
            input type: "text", class: "form-control", id: "dict-word-eq",
                  placeholder: "e.g. dictionary",
                  value: params.dig(:q, :word_eq)
          end
          div class: "col-md-2" do
            label "Word contains", class: "form-label"
            input type: "text", class: "form-control", id: "dict-word-cont",
                  placeholder: "slower / fuzzy",
                  value: params.dig(:q, :word_cont)
          end
          div class: "col-md-2" do
            label "Part of speech", class: "form-label"
            select class: "form-select", id: "dict-pos" do
              # Arbre drops empty attributes, so `option "All", value: ""` renders
              # <option>All</option> and the browser submits "All" as pos_eq.
              text_node '<option value="">All</option>'.html_safe
              DictionaryEntry::POS_OPTIONS.each do |pos|
                option pos, value: pos, selected: (params.dig(:q, :pos_eq) == pos)
              end
            end
          end
          div class: "col-md-2" do
            label "Line #", class: "form-label"
            input type: "number", class: "form-control", id: "dict-line",
                  placeholder: "optional",
                  value: params.dig(:q, :line_number_eq)
          end
        end
        div class: "row mt-3" do
          div class: "col-12" do
            button "Search", type: "button", class: "btn btn-primary me-2", id: "dict-apply-filters"
            a "Clear", href: admin_dictionary_entries_path, class: "btn btn-outline-secondary"
            span class: "text-muted small ms-3" do
              "Tip: “starts with” uses a prefix index; “contains” uses trigram and is heavier."
            end
          end
        end
      end
    end

    div class: "table-responsive" do
      table class: "table table-striped table-hover" do
        thead class: "table-dark" do
          tr do
            th "Word"
            th "POS"
            th "Lang"
            th "Senses"
            th "Line"
            th "Actions", class: "text-end"
          end
        end
        tbody do
          if collection.empty?
            tr do
              td colspan: 6, class: "text-center text-muted py-4" do
                "No dictionary entries match these filters."
              end
            end
          end
          collection.each do |entry|
            tr do
              td do
                span class: "fw-semibold" do entry.word end
              end
              td do
                span class: "badge bg-info" do entry.pos end
              end
              td do
                span class: "text-muted" do "#{entry.lang} (#{entry.lang_code})" end
              end
              td do
                span class: "badge bg-secondary" do entry.senses_count end
              end
              td do
                span class: "text-muted small" do entry.line_number end
              end
              td class: "text-end" do
                link_to "View", admin_dictionary_entry_path(entry), class: "btn btn-sm btn-outline-primary"
              end
            end
          end
        end
      end
    end

    script do
      raw <<~JS
        document.addEventListener('DOMContentLoaded', function() {
          var applyBtn = document.getElementById('dict-apply-filters');
          if (!applyBtn) return;

          function submitSearch() {
            var params = new URLSearchParams();
            var start = document.getElementById('dict-word-start').value.trim();
            var exact = document.getElementById('dict-word-eq').value.trim();
            var cont = document.getElementById('dict-word-cont').value.trim();
            var pos = document.getElementById('dict-pos').value;
            var line = document.getElementById('dict-line').value.trim();

            if (start) params.set('q[word_start]', start);
            if (exact) params.set('q[word_eq]', exact);
            if (cont) params.set('q[word_cont]', cont);
            if (pos) params.set('q[pos_eq]', pos);
            if (line) params.set('q[line_number_eq]', line);

            var url = #{admin_dictionary_entries_path.to_json};
            if (params.toString()) url += '?' + params.toString();
            window.location.href = url;
          }

          applyBtn.addEventListener('click', submitSearch);
          ['dict-word-start', 'dict-word-eq', 'dict-word-cont', 'dict-line'].forEach(function(id) {
            var el = document.getElementById(id);
            if (el) el.addEventListener('keydown', function(e) {
              if (e.key === 'Enter') { e.preventDefault(); submitSearch(); }
            });
          });
        });
      JS
    end
  end

  show do
    entry = resource
    payload = entry.payload.is_a?(Hash) ? entry.payload : {}

    div class: "d-flex justify-content-between align-items-center mb-4" do
      div do
        h1 class: "mb-1 fw-bold text-dark" do
          text_node entry.word
          span class: "badge bg-info ms-2" do entry.pos end
        end
        para class: "text-muted mb-0" do
          "#{entry.lang} (#{entry.lang_code}) · line #{entry.line_number} · #{entry.senses_count} sense(s)"
        end
      end
      div do
        link_to "Back to Dictionary", admin_dictionary_entries_path, class: "btn btn-outline-secondary"
      end
    end

    div class: "row g-4" do
      div class: "col-lg-4" do
        div class: "materio-card mb-4" do
          div class: "materio-header" do
            h5 class: "mb-0 fw-semibold" do
              i class: "ri ri-information-line me-2"
              text_node "Entry"
            end
          end
          div class: "card-body p-4" do
            {
              "Word" => entry.word,
              "Part of speech" => entry.pos,
              "Language" => "#{entry.lang} (#{entry.lang_code})",
              "Etymology #" => entry.etymology_number.presence || "—",
              "Senses" => entry.senses_count,
              "Source file line" => entry.line_number,
              "SHA-256" => truncate(entry.raw_sha256, length: 20),
              "Original title" => entry.original_title.presence || "—",
              "Source field" => entry.source.presence || "—"
            }.each do |label, value|
              div class: "mb-3" do
                div class: "text-muted small fw-semibold mb-1" do label end
                div class: "fw-semibold text-dark text-break" do value end
              end
            end
          end
        end
      end

      div class: "col-lg-8" do
        if entry.etymology_text.present?
          div class: "materio-card mb-4" do
            div class: "materio-header" do
              h5 class: "mb-0 fw-semibold" do
                i class: "ri ri-node-tree me-2"
                text_node "Etymology"
              end
            end
            div class: "card-body p-4" do
              pre class: "mb-0 small", style: "white-space: pre-wrap; max-height: 240px; overflow: auto;" do
                entry.etymology_text
              end
            end
          end
        end

        senses = payload['senses']
        if senses.is_a?(Array) && senses.any?
          div class: "materio-card mb-4" do
            div class: "materio-header" do
              h5 class: "mb-0 fw-semibold" do
                i class: "ri ri-book-open-line me-2"
                text_node "Senses (#{senses.size})"
              end
            end
            div class: "card-body p-4" do
              senses.first(50).each_with_index do |sense, idx|
                next unless sense.is_a?(Hash)

                div class: "border-bottom pb-3 mb-3" do
                  div class: "fw-semibold mb-1" do "Sense #{idx + 1}" end
                  glosses = sense['glosses'] || sense['raw_glosses']
                  if glosses.is_a?(Array)
                    ul class: "mb-2" do
                      glosses.each { |g| li g.to_s }
                    end
                  end
                  if sense['tags'].is_a?(Array) && sense['tags'].any?
                    div class: "mb-1" do
                      sense['tags'].first(12).each do |tag|
                        span class: "badge bg-light text-dark me-1" do tag end
                      end
                    end
                  end
                  examples = sense['examples']
                  if examples.is_a?(Array) && examples.any?
                    div class: "small text-muted" do
                      text_node "Example: "
                      ex = examples.first
                      text_node(ex.is_a?(Hash) ? (ex['text'] || ex.to_json) : ex.to_s)
                    end
                  end
                end
              end
              if senses.size > 50
                para class: "text-muted small mb-0" do
                  "Showing first 50 of #{senses.size} senses. Full data is in payload / raw JSON below."
                end
              end
            end
          end
        end

        # Compact summaries for other large nested arrays
        %w[forms sounds synonyms antonyms translations derived related descendants
           hypernyms hyponyms meronyms holonyms coordinate_terms categories wikipedia].each do |key|
          value = payload[key]
          next unless value.is_a?(Array) && value.any?

          div class: "materio-card mb-3" do
            div class: "materio-header" do
              h5 class: "mb-0 fw-semibold" do
                "#{key.humanize} (#{value.size})"
              end
            end
            div class: "card-body p-3" do
              pre class: "mb-0 small", style: "white-space: pre-wrap; max-height: 200px; overflow: auto;" do
                JSON.pretty_generate(value.first(30))
              end
              if value.size > 30
                para class: "text-muted small mt-2 mb-0" do
                  "Showing first 30 of #{value.size}."
                end
              end
            end
          end
        end

        div class: "materio-card mb-4" do
          div class: "materio-header" do
            h5 class: "mb-0 fw-semibold" do
              i class: "ri ri-code-s-slash-line me-2"
              text_node "Raw JSON (letter-perfect file line)"
            end
          end
          div class: "card-body p-3" do
            para class: "text-muted small" do
              "Length: #{number_with_delimiter(entry.raw_json.bytesize)} bytes · SHA-256: #{entry.raw_sha256}"
            end
            details do
              summary class: "btn btn-sm btn-outline-secondary mb-2" do
                "Reveal raw JSON"
              end
              pre class: "mb-0 small", style: "white-space: pre-wrap; max-height: 480px; overflow: auto; background: #f8f9fa; padding: 1rem;" do
                entry.raw_json
              end
            end
          end
        end
      end
    end
  end
end

# The index block above renders its own header, search card and table. AA's
# default page (1) nests that markup inside an IndexAsTable <table> and (2)
# swaps it for a bare "No Dictionary Entries found" blank slate when a search
# has no hits, which also hides the search card. Rendered via
# app/views/admin/dictionary_entries/index.html.arb.
class DictionaryEntriesIndexPage < ActiveAdmin::Views::Pages::Index
  protected

  def build_collection
    paginated_collection(
      collection,
      entry_name: active_admin_config.resource_label,
      entries_name: active_admin_config.plural_resource_label(count: collection_size),
      download_links: false,
      per_page: config.fetch(:per_page, active_admin_config.per_page)
    ) do
      div class: "index_content" do
        instance_exec(&config.block)
      end
    end
  end
end
