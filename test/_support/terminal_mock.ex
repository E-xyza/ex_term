defmodule ExTermTest.TerminalApi do
  @callback run() :: term
end

Mox.defmock(ExTermTest.TerminalMock, for: ExTermTest.TerminalApi)
