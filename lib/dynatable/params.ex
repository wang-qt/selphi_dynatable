defmodule SelphiDynatable.Params do
  @moduledoc """
  动态表格默认参数，使用 module的opts替换
  """

  @enforce_keys [:query, :repo, :routes, :path, :fields, :module, :csrf_token]

  @type column :: atom
  @type op :: String.t()
  @type function_name :: atom

  @type t :: %__MODULE__{
               # required
               query: Ecto.Query.t(),
               repo: module,
               routes: module,
               path: atom,
               fields: [{column, keyword}],
               filters: [{column, op,  any}], # 字段， 比较符，根据op不同，值可以为 integer, string, list, [start,end]等
               module: module,
               csrf_token: String.t(),
               # optional
               order: [{:asc | :desc, column}] | nil,
               parent: struct | nil,    # 关系，父元素
               belongs_to: atom | nil,  # eg. Post shcema中首先定义 belongs_to(:user, SelphiCms.Accounts.User)
               page: pos_integer,       # 分页: 当前页
               total: non_neg_integer,  # 分页: 记录总数
               list: [struct],          # 查询结果
               search: String.t(),
#               show_field_buttons: boolean,
               action_buttons: [{{atom, map}}],
               batch_actions: [{atom, map}],
               per_page: pos_integer,   # 分页: 分页大小
               debounce: pos_integer,
#               refresh: boolean,
#               disable_hide: boolean,
#               pagination: [:top | :bottom],
               assigns: map,
#               text: module,  # 国际化
#               formatter: {module, function_name} | {module, function_name, list}
             }

  defstruct [
    # required
    :query,
    :repo,
    :routes,
    :path,
    :fields,
    :module,
    :csrf_token,
    # optional
    :order,
    :parent,
    :belongs_to,
    page: 1,
    total: 0,
    list: [],
    filters: nil,
    search: "",
#    show_field_buttons: false,
    action_buttons: [
            show: %{icon: "eye", label: "查看"},
            edit: %{icon: "pencil-alt", label: "编辑"},
            delete: %{icon: "trash", label: "删除"}
           ],
    # 配置批量操作, 系统默认支持 删除选中 导出选中，
    # 用户自定义批量操作，需要自己实现相应的批处理功能。
    batch_actions: [],
    per_page: 20,
    debounce: 300,
#    refresh: false,
#    disable_hide: false,
#    pagination: [:top, :bottom],
    assigns: %{},
#    text: Exzeitable.Text.Default,
#    formatter: {Format, :format_field}
  ]

  @default_fields [
    label: nil,       # Column 的 title
    function: false,
    hidden: false,    # Column 的 hide
    search: true,
    order: true,       # Column 的 sort
#    formatter: {Format, :format_field}
  ]

  @virtual_fields [
    function: true,
    search: false,
    order: false
  ]

  @default_batch_actions  [
        batch_delete:  %{icon: "x", label: "删除选中"},
        batch_export: %{icon: "cloud-download", label: "导出选中"},
  ]

  @doc "Gets fields from options and merges it into the defaults"
  @spec set_fields(keyword) :: [any]
  def set_fields(opts) do
    opts
    |> Keyword.get(:fields, [])
    |> Enum.map(fn {key, field} -> {key, merge_fields(field)} end)
  end

  # If virtual: true, a number of other options have to be overridden
  @spec merge_fields(keyword) :: keyword
  defp merge_fields(field) do
    if Keyword.get(field, :virtual) do
      @default_fields
      |> Keyword.merge(field)
      |> Keyword.merge(@virtual_fields)
    else
      Keyword.merge(@default_fields, field)
    end
  end

  @spec merge_batch_actions(keyword) :: keyword
  defp merge_batch_actions(opts) do
    opts
    |> Keyword.get(:batch_actions)
    |> then(&Keyword.merge(@default_batch_actions , &1))
  end


  @spec new(keyword, keyword, atom) :: map
  def new(function_opts, module_opts, module) do

    # 把 field的value 从 keyword 转化为 map
    fields =
      module_opts
      |> set_fields()
      |> Enum.map(fn {k, f} -> {k, Enum.into(f, %{})} end)

    # 添加 默认批处理 action
    batch_actions =   module_opts |> merge_batch_actions()

    token = Phoenix.Controller.get_csrf_token()

    module_opts
    |> Keyword.merge(function_opts)
    |> Map.new()
    |> Map.merge(%{fields: fields, module: module, csrf_token: token , batch_actions: batch_actions}) # 重写field，添加 module和csrf_token
#    |> Validations.paired_options()
#    |> Validations.required_keys_present(@enforce_keys)
    |> then(&struct!(__MODULE__, &1))  # 创建 结构 Dynatable.Params
    |> then(&%{"params" => &1})        # 创建 map

  end


end