-- O transporte extended opcode foi REMOVIDO por completo (msgID 0x32 nas duas direções, o dispatcher
-- onExtendedOpcode, as tabelas extendedCallbacks/extendedJSONCallbacks e o chunker S/P/E). Todo pacote
-- custom hoje tem seu próprio opcode em Proto:: com parse em C++ chamando g_lua.callGlobalField.
-- Para receber um pacote novo: adicione o número em protocolcodes.h, um `case` em parsePacket, uma
-- parseX em protocolgameparse.cpp e conecte o callback com connect(g_game, {onX = onX}).
local opcodeCallbacks = {}

function ProtocolGame:onOpcode(opcode, msg)
  for i, callback in pairs(opcodeCallbacks) do
    if i == opcode then
      callback(self, msg)
      return true
    end
  end
  return false
end

function ProtocolGame.registerOpcode(opcode, callback)
  if opcodeCallbacks[opcode] then
    error('opcode ' .. opcode .. ' already registered will be overriden')
  end

  opcodeCallbacks[opcode] = callback
end

function ProtocolGame.unregisterOpcode(opcode)
  opcodeCallbacks[opcode] = nil
end

