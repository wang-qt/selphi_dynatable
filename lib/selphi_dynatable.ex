defmodule  SelphiDynatable do
  @moduledoc """
  动态表格组件，简化表格开发，根据配置动态构造查询。
  """

  @doc """
  在 livetable 展开，包含 livetable 所需基础功能。
  使用方法，在 livetable 模块，
  defmodule SelphiCmsWeb.Live.Tables.PostTable  do
    alias SelphiCms.Posts.Post     # 模型
    alias SelphiCmsWeb.Router.Helpers, as: Routes

    use SelphiDynatable,
      repo:   SelphiCms.Repo,                 # 仓库
      routes: Routes,
      path: :post_path,                  # 资源base地址(url)
      fields: [title: [], content: []],  # 字段配置，也可以在模版配置
      query: from(p in Post),            # 基础查询
      refresh: 5000

     ...

  end
  """
  defmacro __using__(opts) do
    quote do
      #      use Phoenix.LiveView
      # 使用工程自己添加
#      use SelphiCmsWeb, :surface_view
#      use Surface.LiveView

      alias SelphiDaisy.{Table, Pagination, Button, Avatar}
      alias SelphiDaisy.Table.Column

      alias SelphiDaisy.Menu
      alias SelphiDaisy.Menu.{Item,SubMenu}
      alias Surface.Components.{Link, LiveRedirect, LivePatch}
      alias SelphiDaisy.Dropdown
      alias SelphiDaisy.Dropdown.Label
      alias SelphiDaisy.Heroicons

      import Ecto.Query
      alias Phoenix.LiveView.Helpers
      alias SelphiDynatable.{Database, Params, Validation}

      @callback render(map) :: {:ok, iolist}
      @type socket :: Phoenix.LiveView.Socket.t()

      @doc """
      方便方法，直接在模版(liveview 或 普通模版)中调用动态表格,
      live_table 函数的参数 opts 是 fuction_opts,
      表格模块中 use SelphiDynatable, opts  是 module_opts
      fuction_opts 优先级高于 module_opts

      ## Example

      ```
      <%= SelphiCmsWeb.LiveTable.PostTable.live_table(@conn, query: @query) %>
      ```

      """
      @spec live_table(Plug.Conn.t(), keyword) :: {:safe, iolist}
      def live_table(conn, opts \\ []) do
        Helpers.live_render(conn, __MODULE__,
          # Live component ID
          id: Keyword.get(unquote(opts), :id, 1),
          session: Params.new(opts, unquote(opts), __MODULE__)
        )
      end

      ###########################
      ######## CALLBACKS ########
      ###########################
      @doc "用于在模版中调用 live_table 使用"
      @spec mount(atom, map, socket) :: {:ok, socket}
      def mount(:not_mounted_at_router, assigns, socket) do

        assigns = Map.new(assigns, fn {k, v} -> {String.to_atom(k), v} end)

        socket =
          socket
          |> assign(assigns)
          |> maybe_get_records()
        #          |> maybe_set_refresh()

        {:ok, socket}
      end

      @doc """
      用于直接在路由配置,eg. live "/live-posts", Live.Tables.PostTable" 时使用
      """
      @spec mount(map, map, socket) :: {:ok, socket}
      def mount(_params, session, socket) do
        IO.puts "SelphiDynatable  mounted!!! "
        IO.inspect   session

        #    assigns = Map.new(assigns, fn {k, v} -> {String.to_atom(k), v} end)
        st_params = Params.new([], unquote(opts) , __MODULE__)
        assigns = Map.new(st_params, fn {k, v} -> {String.to_atom(k), v} end)

        socket =
          socket
          |> assign(assigns)
          |> maybe_get_records()
        #          |> maybe_set_refresh()

        {:ok, socket }
      end



      ###########################
      ######## 事件处理 bgn ########
      ###########################

      # 改变分页， 原理 Pagination 组件点击后，向liveview 发送 :page_change 事件，携带 新页码
      # 1. 修改 socket.assigns.params.page , 然后重新获取分页数据
      # 2. 通知前端 js 重新设置 checkbox 事件，因为前端 checkbox对应新分页记录
      def handle_info({:page_change, value }, %{assigns: %{params: params}} = socket) do
        IO.puts "LiveTable :page_change event!"
        IO.inspect value
        new_params = Map.put(params, :page, value )

        #  必须写成 socket = socket |> 的格式
        socket=
          socket
          |> assign_params(:page, new_params.page)
          |> assign_params(:list, Database.get_records(new_params))
        #        |> assign(:data_list, Database.get_records(new_params))

        # 当 分页，分页大小，排序，搜索发生改变后，通知前端 js hook 重新设置 checkbox 事件
        message = %{
          type: "page_change",
          content: "rows chenged You should refresh check-results !"
        }
        {:noreply,  push_event(socket, "refresh-check-results", message) }
        #    {:noreply, socket}
      end

      # 查看/隐藏 字段
      def handle_event("view_fields_change", %{ } = message ,
            %{assigns: %{params: %Params{fields: fields} } } = socket) do
        IO.puts "收到 view_fields_change change 事件！"
        IO.inspect message
        # message   格式
        #%{
        #  "_target" => ["id"],
        #  "content" => "true",
        #  "id" => "true",
        #  "inserted_at" => "true",
        #  "price" => "true",
        #  "rating" => "true",
        #  "read_count" => "true",
        #  "title" => "true",
        #  "user_id" => "true"
        #}

        # 根据message的字段，重新设置 fields 每个字段的 hidden 属性， message中字段 false 对应 hidden true
        # fields 格式
        #[
        #  id: %{function: false, hidden: true, label: nil, order: true, search: true},
        #  ...
        #]
        new_fields =
          fields
          |> Enum.map(fn {k, f} ->
            {k,  Map.put(f, :hidden,
              !String.to_existing_atom(Map.get(message, to_string(k))) ) }
          end)

        #        IO.puts " new_fields :"
        #        IO.inspect new_fields

        socket=
          socket
          |> assign_params(:fields, new_fields)

        {:noreply, socket }
      end

      # 搜索表单改变事件
      def handle_event("change", %{"search" => search } = message ,
            %{assigns: %{params:  %Params{fields: fields, filters: filters} = params} } = socket) do
        IO.puts "收到 Search form change 事件！"
        IO.inspect message
        # message 格式
        #%{
        #  "_csrf_token" => "EAt_RS4WOChFE1kLd3Y3Bld5WyYUAVo_W306xSlQ5J5cOGb45A7ClThJ",
        #  "_target" => ["search", "id"],
        #  "search" => %{
        #    "content" => "",
        #    "content_op" => "==",
        #    "id" => "1",
        #    "id_op" => "==",
        #    "inserted_at" => "",
        #    "inserted_at_op" => "==",
        #    "price" => "",
        #    "price_op" => "==",
        #    "rating" => "",
        #    "rating_op" => "==",
        #    "read_count" => "",
        #    "read_count_op" => "==",
        #    "title" => "",
        #    "title_op" => "==",
        #    "user_id" => "",
        #    "user_id_op" => "=="
        #  }
        #}
        # 构造 filters , 每个字段为 三元组 {字段, 比较符, 值 }
        #   %{@assigns | filters: [ {:id, "==" , 1  }, {:title, "ilike", "%wang%"}  ]} #
        #   |> Database.get_records()

        # 对于 date-range 和 datetime-range，上报的字段名,不是原始字段名，
        # 而是在原始字段上添加 _bgn或 _end 后缀，需要对 range 类型进行预处理。
        #         search = %{
        #            "is_lock" => "0",
        #            "is_online" => "1",
        #            "inserted_at_bgn" => "2022-04-01",
        #            "inserted_at_end" => "2022-04-11",
        #            "updated_at_bgn" => "2022-04-02",
        #            "updated_at_end" => "2022-04-12",
        #          }
        # 转化为 如下类型
        # %{
        #  "inserted_at" => ["2022-04-01", "2022-04-11"],
        #  "inserted_at_bgn" => "2022-04-01",
        #  "inserted_at_end" => "2022-04-11",
        #  "is_lock" => "0",
        #  "is_online" => "1",
        #  "updated_at" => ["2022-04-02", "2022-04-12"],
        #  "updated_at_bgn" => "2022-04-02",
        #  "updated_at_end" => "2022-04-12"
        #}
        search =
          search
          |> Enum.filter(fn {k, v} -> String.ends_with?(k, "_bgn") || String.ends_with?(k, "_end")  end)
          |> Enum.map(fn {k, v} -> { String.slice(k, 0..-5), v } end)  # [ { "inserted_at" ,  "2022-04-01"},  { "inserted_at" ,  "2022-04-11"}]
          |> Enum.group_by(fn {k, v} -> k end, fn {k, v} -> v end )   #  %{"inserted_at" => ["2022-04-01", "2022-04-11"]}
          |> then(&Map.merge(search, &1))

        new_filters =
          fields
          |> Enum.filter( fn {k, f} ->  Map.get(search, to_string(k), "") != ""  end)   # 过滤出不为 "" 的字段
          |> Enum.map( fn {k, f} ->
            {k,  Map.get(search, to_string(k)<>"_op") , Map.get(search, to_string(k)) }
          end)
          |> Enum.map(fn {k, op, value} ->
            case op do
              "between" -> {k, op , String.split(value,",")}
              "in" -> {k, op , String.split(value,",")}
              "ilike_bgn" -> {k, op , String.split(value,",")}
              "ilike_end" -> {k, op , String.split(value,",")}
              "ilike_and" -> {k, op , String.split(value,",")}
              "ilike_or" -> {k, op , String.split(value,",")}
              _ ->  {k, op , value}
            end
          end)



        IO.puts   "new_filters:"
        IO.inspect new_filters

        new_params =
          params
          |> Map.put( :page, 1 )
          |> Map.put( :filters, new_filters )

        #        IO.puts   "new_params:"
        #        IO.inspect new_params

        #  必须写成 socket = socket |> 的格式
        socket=
          socket
          |> assign_params(:page, new_params.page)
          |> assign_params(:filters, new_params.filters)
          |> assign_params(:total, Database.get_record_count(new_params) )
          |> assign_params(:list, Database.get_records(new_params))

        # 当 分页，分页大小，排序，搜索发生改变后，通知前端 js hook 重新设置 checkbox 事件
        message = %{
          type: "filter_change",
          content: "rows chenged You should refresh check-results !"
        }
        {:noreply, push_event(socket, "refresh-check-results", message)  }
        #        {:noreply, socket }
      end

      def handle_event("submit",
            %{"search" => %{ } } = message ,
            %{assigns: %{params: params}} = socket) do
        IO.puts "收到 Search form submit 事件！"
        IO.inspect message


        {:noreply, socket }
      end


      # 重置搜索条件
      def handle_event("reset_search", _message ,
            %{assigns: %{params:  %Params{fields: fields, filters: filters} = params} } = socket) do

        new_params =
          params
          |> Map.put( :page, 1 )
          |> Map.put( :filters, nil )

        #  必须写成 socket = socket |> 的格式
        socket=
          socket
          |> assign_params(:page, new_params.page)
          |> assign_params(:filters, new_params.filters)
          |> assign_params(:total, Database.get_record_count(new_params) )
          |> assign_params(:list, Database.get_records(new_params))

        # 当 分页，分页大小，排序，搜索发生改变后，通知前端 js hook 重新设置 checkbox 事件
        message = %{
          type: "reset_search",
          content: "rows chenged You should refresh check-results !"
        }
        {:noreply, push_event(socket, "refresh-check-results", message)  }
        #        {:noreply, socket }
      end


      # 分页大小改变事件， 重新查询第一页
      def handle_event("page_size_change",
            %{ "page_size" => %{"size" => size } } = message ,
            %{assigns: %{params: params}} =socket) do

        IO.puts "收到 page_size_change change 事件！"
        IO.inspect message
        new_size = String.to_integer(size)

        # 构造新查询参数, 同时修改分页大小 和 页码，就是每次修改 分页大小，都重新查询第一页
        new_params = Map.merge(params, %{per_page: new_size, page: 1})

        socket =
          socket
          |> assign_params(:page, 1)
          |> assign_params(:per_page, new_size )
          |> assign_params(:list, Database.get_records(new_params))
        #        |> then(&{:noreply, &1})

        # 当 分页，分页大小，排序，搜索发生改变后，通知前端 js hook 重新设置 checkbox 事件
        message = %{
          type: "page_size_change",
          content: "rows chenged You should refresh check-results !"
        }
        {:noreply, push_event(socket, "refresh-check-results", message)  }

        #        {:noreply, socket }
      end

      # TBD 此事件暂时没有触发
      def handle_event("page_size_submit",
            %{ "page_size" => %{"size" => size } } = message ,
            %{assigns: %{params: params}} = socket) do

        IO.puts "收到 page_size_submit submit 事件！"
        IO.inspect message

        new_size = String.to_integer(size)
        # 构造新查询参数
        new_params = Map.merge(params, %{per_page: new_size, page: 1})

        socket
        |> assign_params(:page, 1)
        |> assign_params(:per_page, new_size)
        |> assign_params(:list, Database.get_records(new_params))
          #        |> assign(:data_list, Database.get_records(new_params))
        |> then(&{:noreply, &1})

        #        {:noreply, assign(socket, :per_page, size)  }
      end

      #  字段排序
      def handle_event("sort_change",
            %{"field" => field, "order" => order  } = message ,
            %{assigns: %{params: params}} = socket) do
        IO.puts "收到 sort_change change 事件！"
        IO.inspect message

        # 更新表头ui
        send_update(SelphiDaisy.Table, id: "live-table", sort_field: field, sort_order: order )

        # values = [asc: :name, desc: :population]
        new_order =
          case  order do
            "asc" -> [asc: String.to_atom(field)]
            "desc" -> [desc: String.to_atom(field)]
          end

        new_params = Map.merge(params, %{order: new_order, page: 1})

        socket =
          socket
          |> assign_params(:page, 1)
          |> assign_params(:order, new_order)
          |> assign_params(:list, Database.get_records(new_params))
        #        |> then(&{:noreply, &1})

        # 当 分页，分页大小，排序，搜索发生改变后，通知前端 js hook 重新设置 checkbox 事件
        message = %{
          type: "sort_change",
          content: "rows chenged You should refresh check-results !"
        }
        {:noreply, push_event(socket, "refresh-check-results", message)  }

        #        {:noreply, socket }
      end
      # 字段第一次点击，只更新表头ui
      def handle_event("sort_change", %{"field" => field } = message , socket) do
        IO.puts "收到 sort_change change 事件！"
        IO.inspect message

        send_update(SelphiDaisy.Table, id: "live-table", sort_field: field, sort_order: nil )

        {:noreply, socket }
      end



      #  批量处理 事件
      def handle_event("batch_delete", %{"ids" => ids } = message ,
            %{assigns: %{params:  %Params{query: query, repo: repo } = params} } = socket) do
        IO.puts "收到 batch_delete  事件！"
        IO.inspect message

        # 去掉尾部的 "," 号
        ids = String.trim_trailing(ids,",")

        # 转化为 list，eg.["3", "4", "5", "7", "8", "9"]
        id_list = String.split(ids, ",")

        # 删除时，必须去掉 预加载的 关系！！
        {count, _ } =
          from( q in exclude(query, :preload ), where: q.id in ^id_list)
          |> repo.delete_all()

        socket =
          socket
          |> put_flash( :info, "成功删除 #{count}条记录!")
          |> assign_params(:total, Database.get_record_count(params) )
          |> assign_params(:list, Database.get_records(params))

        # 当 分页，分页大小，排序，搜索发生改变后，通知前端 js hook 重新设置 checkbox 事件
        message = %{
          type: "batch_delete",
          content: "rows chenged You should refresh check-results !"
        }
        {:noreply, push_event(socket, "refresh-check-results", message)  }

        #        {:noreply, socket }
      end

      # 导出选中记录
      def handle_event("batch_export", %{ } = message , socket) do
        IO.puts "收到 batch_export  事件！"
        IO.inspect message

        {:noreply, socket }
      end

      # 导出数据库中所有记录
      def handle_event("exports_all", %{ } = message , socket) do
        IO.puts "收到 exports_all  事件！"
        IO.inspect message

        {:noreply, socket }
      end

      #  单条记录删除 事件
      def handle_event("delete", %{"id" => id } = message ,
            %{assigns: %{params:  %Params{query: query, repo: repo } = params} } =socket) do
        IO.puts "收到 delete  事件！"
        IO.inspect message

        #        query = from(q in query, where: field(q, :id) == ^String.to_integer(id))

        # 删除时，必须去掉 预加载的 关系！！
        record = repo.get!( exclude(query, :preload ) , String.to_integer(id))

        socket = case repo.delete record do
          {:ok, _record} ->
            socket
            |> put_flash( :info, "删除记录#{id}成功!")
            |> assign_params(:total, Database.get_record_count(params) )
            |> assign_params(:list, Database.get_records(params))
          {:error, changeset} ->
            socket |> put_flash( :error, "删除记录#{id}失败!")
        end

        # 当 分页，分页大小，排序，搜索发生改变后，通知前端 js hook 重新设置 checkbox 事件
        message = %{
          type: "delete",
          content: "rows chenged You should refresh check-results !"
        }
        {:noreply, push_event(socket, "refresh-check-results", message)  }

        #        {:noreply, socket }
      end




      ###########################
      ######## 事件处理 end ########
      ###########################

      defp maybe_get_records(socket) do
        %{assigns: %{params: params}} = socket

        if connected?(socket) do
          socket
          |> assign_params(:list, Database.get_records(params))
            #          |> assign(:data_list, Database.get_records(params))
          |> assign_params(:total, Database.get_record_count(params))
        else
          socket
          |> assign_params(:list, [])
            #          |> assign(:data_list, [])
          |> assign_params(:total, 0)
        end
      end

      defp assign_params(%{assigns: %{params: params}} = socket, key, value) do
        params
        |> Map.put(key, value)
          #        |> Map.replace(key, value)
        |> then(&assign(socket, :params, &1))
      end

      # 获取字段初始 是否隐藏
      @doc """
      字段初始时，是否隐藏
      """
      @spec get_field_hidden(map, atom) :: boolean
      def get_field_hidden(%{params: %Params{fields: fields}} = assigns, field) do
        # fields 格式
        #[
        #  id: %{function: false, hidden: true, label: nil, order: true, search: true},
        #  ...
        #]

        fields
        |> Keyword.get(field)
        |> Map.get(:hidden)
      end


      # 获取字段  是否能搜索
      @doc """
      字段是否配置了搜索
      """
      @spec get_field_search(map, atom) :: boolean
      def get_field_search(%{params: %Params{fields: fields}} = assigns, field) do
        # fields 格式
        #[
        #  id: %{function: false, hidden: true, label: nil, order: true, search: true},
        #  ...
        #]

        fields
        |> Keyword.get(field)
        |> Map.get(:search)
      end

      ######################################
      ## 构造  new edit  show url 地址，跳转到 mvc 新建 查看 编辑页码
      def build_new_url(assigns = %{
        socket: socket,
        params: %Params{routes: routes, path: path}
      } ) do
        apply(routes, path, [ socket, :new ] )
      end

      #    "/posts/#{id}"
      def build_show_url( assigns = %{
        socket: socket,
        params: %Params{routes: routes, path: path}
      } , id ) do

        apply(routes, path, [ socket, :show, id] )
      end

      #    "/posts/#{id}/edit"
      def build_edit_url( assigns = %{
        socket: socket,
        params: %Params{routes: routes, path: path}
      } , id ) do
        apply(routes, path, [ socket, :edit, id] )

      end

      ######################################

      # 获取父对象
      @doc """
      获取记录关联的父对象，只支持一个父对象
      """
      @spec parent_for(map, Params.t()) :: struct
      def parent_for(entry, %Params{belongs_to: belongs_to}) do
        case Map.get(entry, belongs_to) do
          #      nil -> raise "You need to select the association in :belongs_to"
          nil -> nil
          result when is_struct(result) -> result
        end
      end

      # Returns true if any of the fields have search enabled
      @doc """
      是否启用过滤，当 SelphiDynatable.Params所有字段均为search: false时，隐藏'过滤按钮'
      """
      def search_enabled?(%Params{fields: fields} = params) do
        fields
        |> Enum.filter(fn {_k, field} -> Map.get(field, :search) end)
        |> Enum.any?()
      end


    end
  end

end