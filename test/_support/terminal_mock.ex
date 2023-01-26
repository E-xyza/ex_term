defmodule ExTermTest.TerminalApi do
  @callback run(group_leader :: pid) :: term
end

Mox.defmock(ExTermTest.TerminalMock, for: ExTermTest.TerminalApi)
