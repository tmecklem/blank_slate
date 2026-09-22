defmodule Mix.Tasks.Signoff do
  @shortdoc "Record a passing local CI status on the current commit"

  @moduledoc """
  Runs `mix precommit`, then signs off on the current commit through the
  `gh signoff` GitHub CLI extension. A failing precommit prevents signoff.

      mix signoff [args]

  Arguments are passed straight through to `gh signoff`:

      mix signoff -f
      mix signoff --commit HEAD~1
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    run!("mix", ["precommit"])
    run!("gh", ["signoff" | argv])
  end

  defp run!(executable, args) do
    if System.find_executable(executable) == nil do
      Mix.raise("#{executable} was not found on PATH.")
    end

    {_output, status} =
      System.cmd(executable, args,
        into: IO.stream(:stdio, :line),
        stderr_to_stdout: true
      )

    if status != 0 do
      command = Enum.join([executable | args], " ")
      Mix.raise("#{command} exited with status #{status}.")
    end
  end
end
