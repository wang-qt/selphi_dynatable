defmodule SelphiDynatable.MixProject do
  use Mix.Project

  def project do
    [
      app: :selphi_dynatable,
      version: "0.1.0",
      # umbrella
#      build_path: "../../_build",
#      config_path: "../../config/config.exs",
#      deps_path: "../../deps",
#      lockfile: "../../mix.lock",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true}
#      {:selphi_daisy, in_umbrella: true}
#      {:selphi_daisy, git: "https://gitee.com/wangqingtai/selphi_daisy.git"}
      {:selphi_daisy, git: "https://github.com/wang-qt/selphi_daisy.git"}
    ]
  end
end
