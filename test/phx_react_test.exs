defmodule PhxReactTest do
  use ExUnit.Case

  test "PhxReact.PageSupervisor is running" do
    assert Process.whereis(PhxReact.PageSupervisor) != nil
  end
end
