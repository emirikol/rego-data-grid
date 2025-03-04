module AjaxDataGrid
  module ActionView
    module Helpers
      class TableRenderer
        def initialize(builder, template)
          @builder = builder
          @tpl = template
          @logger = Logging.logger[self.class]
        end

        def render_all
          buffer = ActiveSupport::SafeBuffer.new
          buffer << render_table
          buffer << render_json_init_div if @builder.table_options[:render_init_json]
          buffer << render_javascript_tag if @builder.table_options[:render_javascript_tag]
          buffer
        end

        def render_table
          @tpl.content_tag :div, :'data-grid-id' => @builder.config.grid_id,
                      class: 'grid_table_wrapper',
                      'data-columns_json' => @builder.columns.collect{|c| c.js_options }.to_json do
            if @builder.table_options[:tiles_view]
              tiles_layout
            else
              table_layout do
                table_rows
              end
            end
          end
        end

        def render_javascript_tag
          @tpl.javascript_tag("$.datagrid.helpers.initFromJSON('#{@builder.config.grid_id}');")
        end

        def render_json_init_div
          @tpl.content_tag 'div', class: 'json_init', style: 'display: none' do
            {
              i18n: I18n.t('plugins.data_grid.js'),
              urls: @builder.table_options[:urls],
              columns: @builder.columns.collect{|c| c.js_options },
              server_params: @builder.config.server_params
            }.to_json
          end
        end

        private
        def tiles_layout
          @tpl.content_tag 'div', class: 'tiles_view' do
            buffer = ActiveSupport::SafeBuffer.new
            if @builder.config.model.rows.empty?
              buffer << no_rows_message_contents
            else
              @builder.config.model.rows.each do |entity|
                cls_selected = @builder.config.model.row_selected?(entity) ? ' selected' : ''
                cls = 'grid_row ' << cls_selected
                buffer << @tpl.content_tag('div', class: 'tile ' + cls,
                                      'data-id' => extract_entity_id(entity),
                                      'data-row_title' => @builder.table_options[:row_title].present? ? @builder.table_options[:row_title].call(entity).to_s : nil) do
                  cell_content = extract_tile_content(entity).to_s
                  cell_content unless cell_content.nil?
                end
              end
              buffer << @tpl.content_tag('div', class: 'clear') { '' }
            end
            buffer
          end
        end

        def table_layout
          @tpl.content_tag :table,
                      class: "grid_table #{@builder.config.model.rows.empty? ? 'empty' : ''}",
                      cellpadding: 0,
                      cellspacing: 0 do
            buffer = ActiveSupport::SafeBuffer.new

            # THEAD
            buffer << @tpl.content_tag(:thead) do
              @tpl.content_tag(:tr) do
                thead_buffer = ActiveSupport::SafeBuffer.new

                @builder.columns.each do |c|
                  next unless c.in_view?(@builder.config.active_view) # skip columns that are not in currently active grid view

                  header_cell_options = c.header_cell_options
                  unless c.is_a?(SelectColumn) || c.is_a?(DestroyColumn)
                    if @builder.config.model.has_sort? && c.sort_by.to_s == @builder.config.model.sort_by
                      header_cell_options[:class] << " #{@builder.config.model.sort_direction}" # mark column as sorted
                      header_cell_options['data-sort-direction'] = (@builder.config.model.sort_direction == 'asc' ? 'desc' : 'asc') # change sort direction on next click
                    end
                  end

                  thead_buffer << @tpl.content_tag(:th, header_cell_options) do
                    @tpl.content_tag(:div, class: 'cell') do
                      cell_buffer = ActiveSupport::SafeBuffer.new

                      if c.is_a?(SelectColumn)
                        cell_buffer << @tpl.content_tag(:span, '', class: 'checkbox' + (@builder.config.model.options.selection == :all ? ' selected' : ''))
                      else
                        cell_buffer << @tpl.content_tag(:div, c.title, class: 'maintitle' + (c.sub_title.blank? ? '' : ' with_subtitle'))
                        cell_buffer << @tpl.content_tag(:div, c.sub_title, class: 'subtitle') unless c.sub_title.blank?
                      end

                      if c.qtip?
                        cell_buffer << @tpl.content_tag(:div, c.options[:qtip], class: 'tooltipContents')
                      end

                      cell_buffer
                    end
                  end
                end

                thead_buffer
              end
            end

            # TBODY
            buffer << @tpl.content_tag(:tbody) do
              tbody_buffer = ActiveSupport::SafeBuffer.new

              if @builder.config.model.rows.empty?
                tbody_buffer << @tpl.content_tag(:tr, class: 'no-data') do
                  @tpl.content_tag(:td, colspan: @builder.columns.size) do
                    no_rows_message_contents
                  end
                end
              end

              # Template rows
              tbody_buffer << @tpl.content_tag(:tr, class: 'template destroying') do
                @tpl.content_tag(:td, colspan: @builder.columns.size) do
                  ActiveSupport::SafeBuffer.new.
                   << @tpl.content_tag(:div, @tpl.raw(@builder.config.translate('template_row.destroy')), class: 'message').
                   << @tpl.content_tag(:div, '', class: 'row_action_error').
                   << @tpl.content_tag(:div, '', class: 'original')
                end
              end

              tbody_buffer << @tpl.content_tag(:tr, class: 'template creating') do
                @tpl.content_tag(:td, colspan: @builder.columns.size) do
                  ActiveSupport::SafeBuffer.new.tap do |bffr|
                    bffr << @tpl.content_tag(:div, @tpl.raw(@builder.config.translate('template_row.create')), class: 'message')
                    bffr << @tpl.content_tag(:div, class: 'error') do
                      ActiveSupport::SafeBuffer.new.
                       << @tpl.raw(@builder.config.translate('template_row.create_error')).
                       << @tpl.content_tag(:span, '', class: 'error_message').
                       << @tpl.link_to(I18n.t('application.close'), 'javascript:;', class: 'close')
                    end
                  end
                end
              end

              tbody_buffer << @tpl.content_tag(:tr, class: 'template cell_templates') do
                cell_templates_buffer = ActiveSupport::SafeBuffer.new

                cell_templates_buffer << @tpl.content_tag(:td, class: 'saving') do
                  @tpl.content_tag(:div, class: 'saving') do
                    ActiveSupport::SafeBuffer.new.tap do |bffr|
                      bffr << @tpl.content_tag(:span, class: 'message') do
                        ActiveSupport::SafeBuffer.new.
                          << @tpl.image_tag('ajax_data_grid/spinner-16x16.gif').
                          << @tpl.content_tag(:span, @builder.config.translate('saving'), class: 'text')
                      end
                      bffr << @tpl.content_tag(:div, '', class: 'original')
                    end
                  end
                end

                cell_templates_buffer << @tpl.content_tag(:td, class: 'validation-error') do
                  @tpl.content_tag(:div, class: 'validation-error') do
                    ActiveSupport::SafeBuffer.new.tap do |bffr|
                      bffr << @tpl.content_tag(:div, class: 'message') do
                        ActiveSupport::SafeBuffer.new.
                          << @tpl.content_tag(:span, '', class: 'text').
                          << @tpl.link_to('ok', 'javascript:;', class: 'ok')
                      end
                      bffr << @tpl.content_tag(:div, '', class: 'original')
                    end
                  end
                end

                cell_templates_buffer << @tpl.content_tag(:td, class: 'qtip_editor_loading_message') do
                  @tpl.content_tag(:div, class: 'qtip_editor_loading_message') do
                    ActiveSupport::SafeBuffer.new.
                      << @tpl.image_tag('spinner-10x10.gif').
                      << @builder.config.translate('loading')
                  end
                end

                cell_templates_buffer << @tpl.content_tag(:td, class: 'qtip_editor_loading_failed') do
                  @tpl.content_tag(:div, class: 'qtip_editor_loading_failed') do
                    @builder.config.translate('loading_failed')
                  end
                end

                cell_templates_buffer
              end

              # Actual rows
              tbody_buffer << yield if block_given? # Call method that renders table_rows

              tbody_buffer
            end

            # TFOOT
            if @builder.table_footer_block.present?
              buffer << @tpl.content_tag(:tfoot) do
                aggregated_data = {}
                aggregated_data = @builder.aggregated_data_config.data if @builder.aggregated_data_config.present?
                @tpl.capture(aggregated_data, &@builder.table_footer_block)
              end
            end

            buffer
          end
        end

        def table_rows
          @logger.info "------------------------------------- render_type = #{@builder.table_options[:render_type]}------------------------------------- "
          if @builder.table_options[:render_type] == :content_tag
            table_rows_content_tag
          elsif @builder.table_options[:render_type] == :haml
            @tpl.capture(&method(:table_rows_haml))
          elsif @builder.table_options[:render_type] == :string_plus
            table_rows_string_plus
          elsif @builder.table_options[:render_type] == :string_concat
            table_rows_string_concat
          end
        end

        def table_rows_string_plus
          buffer = ActiveSupport::SafeBuffer.new

          @builder.config.model.rows.each do |entity|
            html = ""
            entity_selected_class = @builder.config.model.row_selected?(entity) ? "selected" : ''
            row_title = @builder.table_options[:row_title].present? ? "data-row_title='#{@builder.table_options[:row_title].call(entity).to_s}'" : ''
            html += "<tr class='grid_row #{entity_selected_class}' data-id='#{extract_entity_id(entity)}' #{row_title}>"
            @builder.columns.each do |c|
              next unless c.in_view?(@builder.config.active_view) # skip columns that are not in currently active grid view

              cell_attributes = c.body_cell_options.update(body_cell_data_options(c, entity))

              html += "<td #{cell_attributes.collect{|k,v| "#{k}='#{v}'"}.join(' ')}>"
              html += "<div class='cell'>"
              if c.is_a?(SelectColumn)
                html += "<span class='checkbox #{entity_selected_class}'></span>"
              elsif c.is_a?(EditColumn)
                cell_content = extract_column_content(c, entity, false)
                if cell_content.nil?
                  url = c.url
                  url = url.call(entity) if url.is_a?(Proc)
                  html += @tpl.link_to(@tpl.image_tag('/images/blank.gif'), url, c.link_to_options)
                else
                  html += cell_content.to_s
                end
              elsif c.is_a?(DestroyColumn)
                cell_content = extract_column_content(c, entity, false)
                if cell_content.nil?
                  url = c.url
                  url = url.call(entity) if url.is_a?(Proc)
                  html += @tpl.link_to(@tpl.image_tag('/images/blank.gif'), 'javascript:;', {'data-url' => url}.update(c.link_to_options))
                else
                  html += cell_content.to_s
                end
              else
                cell_content = extract_column_content(c, entity).to_s
                html += cell_content unless cell_content.nil?
              end
              html += "</div>"
              html += "</td>"
            end
            html += "</tr>"

            buffer << html
          end

          buffer
        end

        def string_concat_row(entity)
          entity_selected_class = @builder.config.model.row_selected?(entity) ? ' selected' : ''
          row_title = @builder.table_options[:row_title].present? ? 'data-row_title="' << @builder.table_options[:row_title].call(entity).to_s << '"' : ''
          html = '<tr class="grid_row ' << entity_selected_class << '" data-id="' << extract_entity_id(entity) << '"' << row_title << '>'
          @builder.columns.each do |c|
            next unless c.in_view?(@builder.config.active_view) # skip columns that are not in currently active grid view

            cell_attributes = c.body_cell_options.update(body_cell_data_options(c, entity))

            html << '<td '
            cell_attributes.each{|k,v| html << k.to_s << '="' << Haml::Helpers.escape_once(v.to_s) << '" '}
            html << '>'
            html << '<div class="cell">'
            if c.is_a?(SelectColumn)
              html << '<span class="checkbox ' << entity_selected_class << '"></span>'
            elsif c.is_a?(EditColumn)
              cell_content = extract_column_content(c, entity, false)
              if cell_content.nil?
                url = c.url
                url = url.call(entity) if url.is_a?(Proc)
                html << @tpl.link_to(@tpl.image_tag('/images/blank.gif'), url, c.link_to_options)
              else
                html << cell_content.to_s
              end
            elsif c.is_a?(DestroyColumn)
              cell_content = extract_column_content(c, entity, false)
              if cell_content.nil?
                url = c.url
                url = url.call(entity) if url.is_a?(Proc)
                html << @tpl.link_to(@tpl.image_tag('/images/blank.gif'), 'javascript:;', {'data-url' => url}.update(c.link_to_options))
              else
                html << cell_content.to_s
              end
            else
              cell_content = extract_column_content(c, entity).to_s
              html << cell_content unless cell_content.nil?
            end
            html << '</div></td>'
          end
          html + '</tr>'
        end

        def table_rows_string_concat
          buffer = ActiveSupport::SafeBuffer.new

          @builder.config.model.rows.each do |entity|
            @builder.aggregated_data_config.aggregator_block.call(entity, @builder.aggregated_data_config.data) if @builder.aggregated_data_config.present?
            if @builder.table_options[:cache_key].present?
              html = Rails.cache.fetch(@builder.table_options[:cache_key].call(entity)) do
                string_concat_row(entity)
              end
            else
              html = string_concat_row(entity)
            end
            buffer << html
          end

          buffer
        end

        def table_rows_haml
          @builder.config.model.rows.each do |entity|
            cls_selected = @builder.config.model.row_selected?(entity) ? ' selected' : ''
            cls = 'grid_row ' << cls_selected
            @tpl.haml_tag :tr, :class => cls, 'data-id' => extract_entity_id(entity), 'data-row_title' => @builder.table_options[:row_title].present? ? @builder.table_options[:row_title].call(entity).to_s : nil do

              @builder.columns.each do |c|
                next unless c.in_view?(@builder.config.active_view) # skip columns that are not in currently active grid view
                @tpl.haml_tag :td, c.body_cell_options.update(body_cell_data_options(c, entity)) do
                  @tpl.haml_tag :div, :class => 'cell' do
                    if c.is_a?(SelectColumn)
                      @tpl.haml_tag :span, :class => 'checkbox' << cls_selected
                    elsif c.is_a?(EditColumn)
                      cell_content = extract_column_content(c, entity, false)
                      if cell_content.nil?
                        url = c.url
                        url = url.call(entity) if url.is_a?(Proc)
                        @tpl.haml_concat @tpl.link_to(@tpl.image_tag('/images/blank.gif'), url, c.link_to_options)
                      else
                        @tpl.haml_concat cell_content.to_s
                      end
                    elsif c.is_a?(DestroyColumn)
                      cell_content = extract_column_content(c, entity, false)
                      if cell_content.nil?
                        url = c.url
                        url = url.call(entity) if url.is_a?(Proc)
                        html += @tpl.link_to(@tpl.image_tag('/images/blank.gif'), 'javascript:;', {'data-url' => url}.update(c.link_to_options))
                      else
                        @tpl.haml_concat cell_content.to_s
                      end
                    else
                      cell_content = extract_column_content(c, entity).to_s
                      @tpl.haml_concat cell_content unless cell_content.nil?
                    end
                  end
                end
              end
            end
          end
        end

        def table_rows_content_tag
          buffer = ActiveSupport::SafeBuffer.new

          @builder.config.model.rows.each do |entity|
            buffer << @tpl.content_tag(:tr,
                                  class: 'grid_row' + (@builder.config.model.row_selected?(entity) ? ' selected' : ''),
                                  'data-id' => extract_entity_id(entity),
                                  'data-row_title' => @builder.table_options[:row_title].present? ? @builder.table_options[:row_title].call(entity).to_s : nil) do

              row_buffer = ActiveSupport::SafeBuffer.new

              @builder.columns.each do |c|
                next unless c.in_view?(@builder.config.active_view) # skip columns that are not in currently active grid view

                row_buffer << @tpl.content_tag(:td, c.body_cell_options.update(body_cell_data_options(c, entity))) do
                  @tpl.content_tag(:div, class: 'cell') do
                    cell_buffer = ActiveSupport::SafeBuffer.new

                    if c.is_a?(SelectColumn)
                      cell_buffer << @tpl.content_tag(:span, '', class: 'checkbox' + (@builder.config.model.row_selected?(entity) ? ' selected' : ''))
                    elsif c.is_a?(EditColumn)
                      cell_content = extract_column_content(c, entity, false)
                      if cell_content.nil?
                        url = c.url
                        url = url.call(entity) if url.is_a?(Proc)
                        cell_buffer << @tpl.link_to(@tpl.image_tag('/images/blank.gif'), url, c.link_to_options)
                      else
                        cell_buffer << cell_content.to_s
                      end
                    elsif c.is_a?(DestroyColumn)
                      cell_content = extract_column_content(c, entity, false)
                      if cell_content.nil?
                        url = c.url
                        url = url.call(entity) if url.is_a?(Proc)
                        cell_buffer << @tpl.link_to(@tpl.image_tag('/images/blank.gif'), 'javascript:;', {'data-url' => url}.update(c.link_to_options))
                      else
                        cell_buffer << cell_content.to_s
                      end
                    else
                      cell_content = extract_column_content(c, entity).to_s
                      cell_buffer << cell_content unless cell_content.nil?
                    end

                    cell_buffer
                  end
                end
              end

              row_buffer
            end
          end

          buffer
        end

        def extract_tile_content(entity)
          tile_config = @builder.tile_config
          value = nil
          buffer = @tpl.with_output_buffer { value = tile_config.block.call(entity) }
          if string = buffer.presence || value and string.is_a?(String)
            ERB::Util.html_escape string
          end
        end

        def extract_column_content(column, entity, throw_error = true)
          if column.block.present?
            @tpl.capture entity, &column.block
          elsif column.binding_path.present?
            extract_entity_value_from_binding_path(entity, column)
          else
            if throw_error
              raise ArgumentError.new("Either block or binding_path must be given for data_grid column: column #{column.title}")
            else
              nil
            end
          end
        end

        def body_cell_data_options(column, entity)
          data_options = {}
          column.data_attributes.each do |attribute, value_path|
            val = extract_entity_value(entity, column, value_path)
            val = URI.escape(val) if val.present? && val.is_a?(String) && column.escape_data_attributes.include?(value_path)
            data_options["data-#{attribute}"] = val
          end
          data_options
        end

        def extract_entity_value_from_binding_path(entity, column)
          raise ArgumentError.new("Binding path is nil for column #{column.title}") if column.binding_path.nil?

          extract_entity_value(entity, column, column.binding_path)
        end

        def extract_entity_value(entity, column, value_path)
          value = nil
          if value_path.is_a?(Symbol) || value_path.is_a?(String)
            raise ArgumentError.new("Entity #{entity.class} doesn't respond to #{value_path}") unless entity.respond_to?(value_path)
            value = entity.send(value_path)
          elsif value_path.is_a?(Proc)
            value = value_path.call(entity)
          else
            raise ArgumentError.new("Don't know how to extract value from value path #{value_path.inspect} for entity #{entity.inspect} ")
          end

          #parse value
          if value.is_a?(Float) || value.is_a?(BigDecimal)
            format = column.value_format.is_a?(String) ? column.value_format : AjaxDataGrid::Column.default_formats[:float]
            value = sprintf(format, value)
          elsif value.is_a?(TrueClass) || value.is_a?(FalseClass)
            value = value.to_s
          end
          value
        end

        def extract_entity_id(entity)
          entity.respond_to?(:id) ? entity.id.to_s : "rand_#{ActiveSupport::SecureRandom.hex}"
        end

        def no_rows_message_contents
          @tpl.content_tag :div, class: 'no-data' do
            if @builder.config.model.any_rows? # any rows at all - no rows in this filter
              no_rows_for_filter
            else # no rows at all
              @tpl.content_tag :div, @builder.table_options[:empty_rows], class: 'no rows'
            end
          end
        end

        def no_rows_for_filter
          @tpl.render 'ajax_data_grid/no_filter_results.html', builder: @builder
        end
      end
    end
  end
end