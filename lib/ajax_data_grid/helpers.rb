module AjaxDataGrid
  module ActionView
    module Helpers

      def data_grid_active_view(cfg)
        content_tag :div, class: 'activeView', 'data-grid-id' => cfg.grid_id do
          ActiveSupport::SafeBuffer.new.
          << content_tag(:span, cfg.translate('views.active_view')).
          << select_tag('active_view', options_for_select(cfg.options.views, selected: cfg.active_view))
        end
      end

      def data_grid_rows_per_page(cfg)
        content_tag :div, class: 'pageSize', 'data-grid-id' => cfg.grid_id do
          buffer = ActiveSupport::SafeBuffer.new
          buffer << content_tag(:span, cfg.translate('rows_per_page.show'))
          buffer << select_tag('paging_page_size', options_for_select(cfg.options.per_page_sizes, selected: cfg.model.rows.per_page))
          buffer << content_tag(:span, cfg.translate('rows_per_page.per_page'))
          buffer
        end
      end

      def data_grid_pagination(cfg)
        content_tag :div, class: 'pages', 'data-grid-id' => cfg.grid_id do
          will_paginate(cfg.model.rows, inner_window: 1, outer_window: 0, link_separator: '', param_name: :paging_current_page)
        end
      end

      def data_grid_pagination_info(cfg)
        content_tag :div, class: 'pagesInfo', 'data-grid-id' => cfg.grid_id do
          page_entries_info(cfg.model.rows)
        end
      end

      def data_grid_toolbar(cfg, options = {}, &block)
        options = {pos: :top}.update(options)
        builder = AjaxDataGrid::ToolbarBuilder.new
        yield builder if block.present?

        content_tag :div, class: ['toolbar', options[:pos]].compact.join(' ') do
          buffer = ActiveSupport::SafeBuffer.new

          # Loading div
          buffer << content_tag(:div, cfg.translate('loading'), 'data-state' => :loading)

          # Normal div
          buffer << content_tag(:div, 'data-state' => :normal) do
            normal_buffer = ActiveSupport::SafeBuffer.new

            # Right wrapper
            normal_buffer << content_tag(:div, class: 'right_wrapper') do
              right_buffer = ActiveSupport::SafeBuffer.new

              if cfg.options.views.size > 1
                right_buffer << data_grid_active_view(cfg)
              end

              if builder.side_controls_block.present?
                right_buffer << content_tag(:div, class: 'side-controls') do
                  capture(&builder.side_controls_block)
                end
              end

              right_buffer
            end

            # Pagination wrapper
            if cfg.model.has_paging?
              normal_buffer << content_tag(:div, class: 'pagination_wrapper') do
                pagination_buffer = ActiveSupport::SafeBuffer.new
                pagination_buffer << data_grid_rows_per_page(cfg)
                pagination_buffer << data_grid_pagination(cfg)
                pagination_buffer << data_grid_pagination_info(cfg)
                pagination_buffer
              end
            end

            normal_buffer
          end

          # Multirow actions
          if builder.multirow_actions_block.present?
            buffer << content_tag(:div, 'data-state' => :multirow_actions, 'data-grid-id' => cfg.grid_id) do
              multirow_buffer = ActiveSupport::SafeBuffer.new
              multirow_buffer << content_tag(:span, raw(cfg.translate('multirow_actions.intro', count: '<span class="count">0</span>')), class: 'intro')
              multirow_buffer << capture(&builder.multirow_actions_block)
              multirow_buffer << link_to(cfg.translate('multirow_actions.close'), 'javascript:;', class: 'btn close_multirow_actions', 'data-action' => :close)
              multirow_buffer
            end
          end

          buffer
        end
      end

      def data_grid_table(cfg, options = {}, &block)
        options = {
                    render_init_json: !request.xhr?,
                    render_javascript_tag: !request.xhr?
                  }.update(options)

        builder = AjaxDataGrid::TableBuilder.new(cfg, options)
        yield builder # user defines columns and their content

        TableRenderer.new(builder, self).render_all
      end

    end
  end
end

#ActionView::Base.send :include, AjaxDataGrid::ActionView::Helpers