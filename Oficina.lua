--[[
  Oficina de Peças — script do objeto.

  Deixa qualquer jogador criar componentes custom (token, tile, figura, carta, modelo 3D) a partir de
  um link de imagem. As caixas de diálogo aparecem só para o jogador que clicou; quem cria a peça
  é o script, então a janela de importação do TTS (que aparece para o host) não é usada.

  Instalação:
    1. Objects > Components > Custom > Model
         Model/Mesh: assets/oficina.obj    Diffuse/Image: assets/oficina.png    (aceite subir para a Cloud)
    2. Clique direito no objeto > Scripting > Scripting Editor, cole este arquivo, Save & Play.
  Funciona também num bloco comum (Objects > Blocks > Square).
]]

--------------------------------------------------------------------------
-- Estado (vai para o save do objeto)
--------------------------------------------------------------------------
D = {
  approval = false,   -- peças de jogadores precisam da aprovação do mestre
  lang = "pt",
  library = {},       -- steam_id -> lista de peças criadas por esse jogador
  queue = {},         -- pedidos esperando aprovação
  nextId = 1,
}

local INNER = { w = 7, d = 9.5 }     -- tampo do modelo (tools/gerar_modelo.py)
local MODEL_TOP = 0.30
local U = 450
local DECAL_ROT = { 90, 180, 0 }     -- se as miniaturas aparecerem de cabeça para baixo, use { 90, 0, 0 }
local LIBRARY_MAX = 40
local QUEUE_SHOWN = 2

-- Tamanhos oferecidos (escala da peça)
local SIZES = {
  { "Pequeno", "Small", 0.6 },
  { "Médio", "Medium", 1.0 },
  { "Grande", "Large", 1.6 },
  { "Enorme", "Huge", 2.5 },
}

-- Formatos do Custom Tile (campo "type" do setCustomObject)
local TILE_SHAPES = {
  { "Quadrado", "Square", 0 },
  { "Hexágono", "Hexagon", 1 },
  { "Redondo", "Round", 2 },
  { "Cantos arredondados", "Rounded corners", 3 },
}

--------------------------------------------------------------------------
-- Idioma
--------------------------------------------------------------------------
local EN = {
  ["Oficina de Peças"] = "Piece Workshop",
  ["Crie peças a partir de um link de imagem"] = "Create pieces from an image link",
  ["Criar"] = "Create",
  ["Token"] = "Token", ["Tile"] = "Tile", ["Figura"] = "Standee", ["Carta"] = "Card", ["Modelo 3D"] = "3D model",
  ["Minha biblioteca"] = "My library",
  ["Use links .png / .jpg (Imgur, Discord, Steam Cloud)"] = "Use .png / .jpg links (Imgur, Discord, Steam Cloud)",
  ["Mestre"] = "Game master",
  ["Aprovação: ligada"] = "Approval: on", ["Aprovação: desligada"] = "Approval: off",
  ["Peças de jogadores só aparecem depois que o mestre aprovar"] = "Players' pieces only appear after the GM approves",
  ["Nenhum pedido pendente"] = "No pending requests",
  ["Aprovar"] = "Approve", ["Recusar"] = "Reject",
  [" pedido(s) a mais"] = " more request(s)",
  ["Idioma"] = "Language",
  -- diálogos
  ["Link da imagem (.png ou .jpg)"] = "Image link (.png or .jpg)",
  ["Link da imagem do verso (deixe vazio para usar a mesma)"] = "Back image link (leave empty to use the same one)",
  ["Link do modelo 3D (.obj)"] = "3D model link (.obj)",
  ["Link da textura (.png ou .jpg) — opcional"] = "Texture link (.png or .jpg) — optional",
  ["Formato do tile"] = "Tile shape",
  ["Nome da peça"] = "Piece name",
  ["Tamanho"] = "Size",
  ["Sua biblioteca"] = "Your library",
  ["O que fazer com \""] = "What to do with \"",
  ["Criar de novo"] = "Create again", ["Apagar da biblioteca"] = "Delete from library",
  -- mensagens
  ["O link precisa começar com http:// ou https://"] = "The link must start with http:// or https://",
  ["Peça criada: "] = "Piece created: ",
  ["Pedido enviado ao mestre: "] = "Request sent to the game master: ",
  ["Novo pedido de peça de "] = "New piece request from ",
  [" (veja a Oficina de Peças)"] = " (see the Piece Workshop)",
  ["O mestre aprovou: "] = "The game master approved: ",
  ["O mestre recusou: "] = "The game master rejected: ",
  ["Sua biblioteca está vazia. Crie uma peça primeiro."] = "Your library is empty. Create a piece first.",
  ["Removido da biblioteca: "] = "Removed from library: ",
  ["Só o mestre (host/admin) pode fazer isso."] = "Only the game master (host/admin) can do that.",
  ["Sente-se numa cor para criar peças."] = "Take a seat (pick a color) to create pieces.",
  ["Criado por "] = "Created by ",
}

function tr(s)
  if D.lang == "en" then return EN[s] or s end
  return s
end

local KIND_LABEL = { token = "Token", tile = "Tile", figure = "Figura", card = "Carta", model = "Modelo 3D" }

--------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------
function onLoad(saved)
  if saved and saved ~= "" then
    local ok, t = pcall(JSON.decode, saved)
    if ok and type(t) == "table" then D = t end
  end
  D.library = D.library or {}
  D.queue = D.queue or {}
  D.nextId = D.nextId or 1
  self.setName(tr("Oficina de Peças"))
  if isModel() then
    self.setScale({ 1, 1, 1 })
  else
    self.setScale({ INNER.w + 0.8, 0.3, INNER.d + 0.8 })
    self.setColorTint({ 0.22, 0.14, 0.08 })
  end
  Wait.frames(build, 5)
end

function onSave()
  return JSON.encode(D)
end

--------------------------------------------------------------------------
-- Utilitários
--------------------------------------------------------------------------
function isModel()
  local co = self.getCustomObject()
  return co ~= nil and co.mesh ~= nil and co.mesh ~= ""
end

function trim(s)
  s = s or ""
  local i, j = 1, #s
  while i <= j and s:sub(i, i):find("%s") do i = i + 1 end
  while j >= i and s:sub(j, j):find("%s") do j = j - 1 end
  return s:sub(i, j)
end

-- Corta textos longos para caber no painel.
function short(s, n)
  if #s <= n then return s end
  return s:sub(1, n - 2) .. ".."
end

function isLink(s)
  return s:sub(1, 7) == "http://" or s:sub(1, 8) == "https://"
end

function tell(color, text)
  if color and Player[color] and Player[color].seated then printToColor(text, color, { 0.95, 0.85, 0.6 }) end
end

function tellGMs(text)
  for _, p in ipairs(Player.getPlayers()) do
    if p.admin then printToColor(text, p.color, { 1, 0.75, 0.35 }) end
  end
end

function isGM(color)
  local p = Player[color]
  if p and p.admin then return true end
  tell(color, tr("Só o mestre (host/admin) pode fazer isso."))
  return false
end

-- As caixas de diálogo do TTS aparecem só para o jogador em que são chamadas.
-- Entre uma e outra esperamos dois frames, senão a segunda pode não abrir.
function ask(p, desc, default, fn)
  Wait.frames(function() p.showInputDialog(desc, default or "", function(text) fn(text) end) end, 2)
end

function choose(p, desc, options, fn)
  Wait.frames(function() p.showOptionsDialog(desc, options, 1, function(text, index) fn(text, index) end) end, 2)
end

function sizeOptions()
  local o = {}
  for _, s in ipairs(SIZES) do table.insert(o, D.lang == "en" and s[2] or s[1]) end
  return o
end

function shapeOptions()
  local o = {}
  for _, s in ipairs(TILE_SHAPES) do table.insert(o, D.lang == "en" and s[2] or s[1]) end
  return o
end

--------------------------------------------------------------------------
-- Criação da peça
--------------------------------------------------------------------------
-- Pede ao jogador, em sequência, o que cada tipo de peça precisa e devolve o pedido montado.
function startCreate(kind, color)
  local p = Player[color]
  if not (p and p.seated) or color == "Grey" then
    return tell(color, tr("Sente-se numa cor para criar peças."))
  end
  local r = { kind = kind, color = color, steam = p.steam_id, pname = p.steam_name }

  local function finish()
    ask(p, tr("Nome da peça"), tr(KIND_LABEL[kind]), function(name)
      r.name = trim(name) ~= "" and trim(name) or tr(KIND_LABEL[kind])
      choose(p, tr("Tamanho"), sizeOptions(), function(_, i)
        r.size = SIZES[i] and SIZES[i][3] or 1
        submit(r)
      end)
    end)
  end

  local function needLink(text)
    text = trim(text)
    if not isLink(text) then
      tell(color, tr("O link precisa começar com http:// ou https://"))
      return nil
    end
    return text
  end

  if kind == "model" then
    ask(p, tr("Link do modelo 3D (.obj)"), "", function(mesh)
      r.url2 = needLink(mesh)
      if not r.url2 then return end
      ask(p, tr("Link da textura (.png ou .jpg) — opcional"), "", function(img)
        img = trim(img)
        r.url = isLink(img) and img or ""
        finish()
      end)
    end)
    return
  end

  ask(p, tr("Link da imagem (.png ou .jpg)"), "", function(img)
    r.url = needLink(img)
    if not r.url then return end
    if kind == "figure" or kind == "card" then
      ask(p, tr("Link da imagem do verso (deixe vazio para usar a mesma)"), "", function(back)
        back = trim(back)
        r.url2 = isLink(back) and back or r.url
        finish()
      end)
    elseif kind == "tile" then
      choose(p, tr("Formato do tile"), shapeOptions(), function(_, i)
        r.shape = TILE_SHAPES[i] and TILE_SHAPES[i][3] or 0
        finish()
      end)
    else
      finish()
    end
  end)
end

-- Com aprovação ligada, pedidos de jogadores comuns vão para a fila do mestre.
function submit(r)
  local p = Player[r.color]
  if D.approval and not (p and p.admin) then
    r.id = D.nextId
    D.nextId = D.nextId + 1
    table.insert(D.queue, r)
    tell(r.color, tr("Pedido enviado ao mestre: ") .. r.name)
    tellGMs(tr("Novo pedido de peça de ") .. (r.pname or r.color) .. ": " .. r.name .. tr(" (veja a Oficina de Peças)"))
    build()
    return
  end
  spawnPiece(r)
end

-- Onde a peça aparece: na frente da mão do jogador, um pouco para dentro da mesa.
function spawnSpot(color)
  local p = Player[color]
  if p and p.seated and p.getHandCount() > 0 then
    local h = p.getHandTransform(1)
    local dx, dz = -h.position.x, -h.position.z
    local len = math.sqrt(dx * dx + dz * dz)
    if len > 0.01 then dx, dz = dx / len, dz / len end
    return { h.position.x + dx * 5, h.position.y + 2, h.position.z + dz * 5 }, h.rotation.y
  end
  local s = self.getPosition()
  return { s.x + INNER.w / 2 + 3, s.y + 2, s.z }, 0
end

function pieceSpec(r)
  if r.kind == "token" then
    return "Custom_Token", { image = r.url, thickness = 0.2, merge_distance = 15, stackable = false }
  elseif r.kind == "tile" then
    return "Custom_Tile", { image = r.url, image_bottom = r.url, type = r.shape or 0, thickness = 0.2, stackable = false }
  elseif r.kind == "figure" then
    return "Figurine_Custom", { image = r.url, image_secondary = r.url2 or r.url }
  elseif r.kind == "card" then
    return "CardCustom", { face = r.url, back = r.url2 or r.url, sideways = false }
  else
    return "Custom_Model", { mesh = r.url2, diffuse = r.url or "", type = 0, material = 0 }
  end
end

function spawnPiece(r)
  local pos, rotY = spawnSpot(r.color)
  local kind, params = pieceSpec(r)
  local s = r.size or 1
  local obj = spawnObject({
    type = kind, position = pos, rotation = { 0, rotY, 0 }, scale = { s, s, s },
    callback_function = function(o)
      o.setName(r.name)
      o.setDescription(tr("Criado por ") .. (r.pname or r.color))
    end,
  })
  obj.setCustomObject(params)
  addToLibrary(r)
  tell(r.color, tr("Peça criada: ") .. r.name)
end

--------------------------------------------------------------------------
-- Biblioteca pessoal (por conta Steam)
--------------------------------------------------------------------------
function addToLibrary(r)
  if not r.steam then return end
  local lib = D.library[r.steam] or {}
  for i = #lib, 1, -1 do
    local e = lib[i]
    if e.kind == r.kind and e.url == r.url and e.url2 == r.url2 and e.name == r.name then table.remove(lib, i) end
  end
  table.insert(lib, { kind = r.kind, url = r.url, url2 = r.url2, shape = r.shape, name = r.name, size = r.size })
  while #lib > LIBRARY_MAX do table.remove(lib, 1) end
  D.library[r.steam] = lib
end

function openLibrary(_, color)
  local p = Player[color]
  if not (p and p.seated) or color == "Grey" then return tell(color, tr("Sente-se numa cor para criar peças.")) end
  local lib = D.library[p.steam_id] or {}
  if #lib == 0 then return tell(color, tr("Sua biblioteca está vazia. Crie uma peça primeiro.")) end
  local opts = {}
  for i = #lib, 1, -1 do table.insert(opts, lib[i].name .. "  (" .. tr(KIND_LABEL[lib[i].kind]) .. ")") end
  choose(p, tr("Sua biblioteca"), opts, function(_, k)
    local idx = #lib - k + 1
    local e = lib[idx]
    if not e then return end
    choose(p, tr("O que fazer com \"") .. e.name .. "\"?", { tr("Criar de novo"), tr("Apagar da biblioteca") }, function(_, j)
      if j == 1 then
        submit({ kind = e.kind, url = e.url, url2 = e.url2, shape = e.shape, name = e.name, size = e.size,
          color = color, steam = p.steam_id, pname = p.steam_name })
      else
        table.remove(lib, idx)
        tell(color, tr("Removido da biblioteca: ") .. e.name)
      end
    end)
  end)
end

--------------------------------------------------------------------------
-- Ações dos botões: (obj, cor, clique_direito)
--------------------------------------------------------------------------
function noop() end
function c_token(_, c) startCreate("token", c) end
function c_tile(_, c) startCreate("tile", c) end
function c_figure(_, c) startCreate("figure", c) end
function c_card(_, c) startCreate("card", c) end
function c_model(_, c) startCreate("model", c) end
function c_library(o, c) openLibrary(o, c) end

function g_approval(_, c)
  if not isGM(c) then return end
  D.approval = not D.approval
  build()
end

function decide(n, c, ok)
  if not isGM(c) then return end
  local r = D.queue[n]
  if not r then return end
  table.remove(D.queue, n)
  if ok then
    spawnPiece(r)
    tell(r.color, tr("O mestre aprovou: ") .. r.name)
  else
    tell(r.color, tr("O mestre recusou: ") .. r.name)
  end
  build()
end
function q1a(_, c) decide(1, c, true) end
function q1r(_, c) decide(1, c, false) end
function q2a(_, c) decide(2, c, true) end
function q2r(_, c) decide(2, c, false) end

function l_pt(_, c) if isGM(c) then D.lang = "pt"; self.setName(tr("Oficina de Peças")); build() end end
function l_en(_, c) if isGM(c) then D.lang = "en"; self.setName(tr("Oficina de Peças")); build() end end

--------------------------------------------------------------------------
-- Desenho do painel
--------------------------------------------------------------------------
local CREAM = { 0.93, 0.89, 0.80 }
local MUTED = { 0.64, 0.60, 0.53 }
local GOLD = { 0.86, 0.68, 0.32 }
local DARK_TXT = { 0.12, 0.08, 0.04 }
local WALNUT = { 0.33, 0.21, 0.12 }
local SLATE = { 0.24, 0.25, 0.29 }
local BRASS = { 0.76, 0.56, 0.22 }
local TEAL = { 0.18, 0.40, 0.36 }
local BRICK = { 0.55, 0.22, 0.14 }
local PLATE = { 0.10, 0.11, 0.13, 0.82 }

-- z positivo = topo do painel (o "para cima" do texto dos botões aponta para o -z local).
function place(x, z)
  local s = self.getScale()
  local top = isModel() and (MODEL_TOP + 0.02) / s.y or (0.5 + 0.02 / s.y)
  return { x / s.x, top, -z / s.z }, { 1 / s.x, 1 / s.y, 1 / s.z }
end

function B(label, fn, x, z, w, h, color, textColor, tip)
  local pos, sc = place(x, z)
  self.createButton({
    label = label, click_function = fn, function_owner = self,
    position = pos, scale = sc,
    width = w * U, height = h * U, font_size = math.floor(h * U * 0.42),
    color = color or WALNUT, font_color = textColor or CREAM,
    hover_color = { 0.52, 0.38, 0.18 }, press_color = { 0.70, 0.52, 0.22 },
    tooltip = tip or "",
  })
end

-- Texto com plaqueta escura atrás (legível mesmo se o tampo ficar claro com a luz).
function T(label, x, z, h, color)
  local pos, sc = place(x, z)
  local fs = math.floor(h * U * 0.62)
  local w = math.min(INNER.w - 0.4, #label * fs * 0.52 / U + 0.4)
  self.createButton({
    label = label, click_function = "noop", function_owner = self,
    position = pos, scale = sc, width = w * U, height = math.floor(h * U * 1.1),
    font_size = fs, font_color = color or CREAM, color = PLATE, hover_color = PLATE, press_color = PLATE,
  })
end

-- Miniatura desenhada no tampo. Os decals usam o x espelhado em relação aos botões.
function decal(name, url, x, z, w, h)
  local s = self.getScale()
  local top = isModel() and (MODEL_TOP + 0.012) / s.y or (0.5 + 0.012 / s.y)
  return { name = name, url = url, position = { -x / s.x, top, -z / s.z }, rotation = DECAL_ROT, scale = { w / s.x, h / s.z, 1 } }
end

function build()
  self.clearButtons()
  local decals = {}
  local W = INNER.w - 0.6
  local half = W / 2 - 0.06
  local x2 = { -W / 4, W / 4 }

  local z = INNER.d / 2 - 0.3
  local function line(h)
    local c = z - h / 2
    z = z - h - 0.12
    return c
  end
  local function gap(h) z = z - h end
  local function heading(text) T(text, -W / 2 + 0.05 + #text * 0.066, line(0.34), 0.34, GOLD) end

  T(tr("Oficina de Peças"), 0, line(0.55), 0.55, GOLD)
  T(tr("Crie peças a partir de um link de imagem"), 0, line(0.3), 0.28, MUTED)
  gap(0.1)

  heading(tr("Criar"))
  local rows = {
    { { "Token", "c_token" }, { "Tile", "c_tile" } },
    { { "Figura", "c_figure" }, { "Carta", "c_card" } },
    { { "Modelo 3D", "c_model" }, { "Minha biblioteca", "c_library" } },
  }
  for _, r in ipairs(rows) do
    local c = line(0.6)
    for k, b in ipairs(r) do
      local lib = b[2] == "c_library"
      B(tr(b[1]), b[2], x2[k], c, half, 0.6, lib and TEAL or BRASS, lib and CREAM or DARK_TXT)
    end
  end
  T(tr("Use links .png / .jpg (Imgur, Discord, Steam Cloud)"), 0, line(0.28), 0.24, MUTED)
  gap(0.15)

  heading(tr("Mestre"))
  local c = line(0.5)
  B(D.approval and tr("Aprovação: ligada") or tr("Aprovação: desligada"), "g_approval", 0, c, W, 0.5,
    D.approval and BRASS or WALNUT, D.approval and DARK_TXT or CREAM,
    tr("Peças de jogadores só aparecem depois que o mestre aprovar"))

  if #D.queue == 0 then
    T(tr("Nenhum pedido pendente"), 0, line(0.32), 0.28, MUTED)
  else
    for n = 1, math.min(QUEUE_SHOWN, #D.queue) do
      local r = D.queue[n]
      local rc = line(0.95)
      local thumbUrl = r.kind == "model" and r.url or r.url
      if thumbUrl and thumbUrl ~= "" then
        table.insert(decals, decal("pedido" .. n, thumbUrl, -W / 2 + 0.5, rc, 0.95, 0.95))
      end
      T(short(r.name, 18), -0.55, rc + 0.2, 0.28, CREAM)
      T(short(r.pname or r.color, 12) .. " · " .. tr(KIND_LABEL[r.kind]), -0.55, rc - 0.2, 0.24, MUTED)
      B(tr("Aprovar"), "q" .. n .. "a", W / 2 - 1.6, rc, 1.0, 0.45, TEAL, CREAM)
      B(tr("Recusar"), "q" .. n .. "r", W / 2 - 0.5, rc, 1.0, 0.45, BRICK, CREAM)
    end
    if #D.queue > QUEUE_SHOWN then
      T("+" .. (#D.queue - QUEUE_SHOWN) .. tr(" pedido(s) a mais"), 0, line(0.28), 0.24, MUTED)
    end
  end

  z = -INNER.d / 2 + 0.3 + 0.45
  c = z - 0.225
  B("Português", "l_pt", x2[1], c, half, 0.45, D.lang ~= "en" and BRASS or SLATE, D.lang ~= "en" and DARK_TXT or CREAM)
  B("English", "l_en", x2[2], c, half, 0.45, D.lang == "en" and BRASS or SLATE, D.lang == "en" and DARK_TXT or CREAM)

  self.setDecals(decals)
end
