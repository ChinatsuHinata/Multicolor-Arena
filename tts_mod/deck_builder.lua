-- Multicolour Arena deck builder for Tabletop Simulator.
-- Generated save embeds the card catalog and the existing mod's image sheets.
local cards = JSON.decode([====[__CATALOG_JSON__]====])
local assets = JSON.decode([====[__ASSETS_JSON__]====])
local by_id = {}
for _, card in ipairs(cards) do by_id[card.id] = card end

local rule_labels = {
    unrestricted = "无限制", official = "官限",
    official_spx = "官限有限定卡", test = "测试卡组"
}
local rule_order = {"unrestricted", "official", "official_spx", "test"}
local official_two = { ["character-ucs-038"] = true, ["104"] = true, ["item-fdf-096"] = true }
local banned_spx = { ["new-spx-001"] = true, ["new-spx-002"] = true, ["new-spx-003"] = true,
    ["new-spx-004"] = true, ["new-spx-005"] = true, ["new-spx-006"] = true, ["new-spx-007"] = true }
local kinds = {"全部", "自机", "单位", "符卡", "道具", "结界"}
local colors = {"全部", "红", "蓝", "绿", "黄", "黑"}
local sorts = {"类别", "颜色值", "名字"}
local kind_rank = { ["自机"] = 0, ["单位"] = 1, ["符卡"] = 2, ["道具"] = 3, ["结界"] = 4 }

local draft = {name = "未命名卡组", main = {}, side = {}, leader = "", rule_set = "official"}
local saved_decks = {}
local selected_saved = ""
local delete_pending = false
local open = false
local search = ""
local kind_filter = "全部"
local selected_colors = {}
local sort_mode = "类别"
local library_page = 1
local main_page = 1
local side_page = 1
local selected_id = ""
local code_text = ""
local message = ""
local preview_object = nil

local function clone(value) return JSON.decode(JSON.encode(value)) end
local function replace_plain(value, needle, replacement)
    local pieces, cursor = {}, 1
    while true do
        local at = value:find(needle, cursor, true)
        if not at then
            pieces[#pieces + 1] = value:sub(cursor)
            return table.concat(pieces)
        end
        pieces[#pieces + 1] = value:sub(cursor, at - 1)
        pieces[#pieces + 1] = replacement
        cursor = at + #needle
    end
end
local function xml(value)
    local result = tostring(value or "")
    for _, replacement in ipairs({{"&", "&amp;"}, {"<", "&lt;"}, {">", "&gt;"},
        {'"', "&quot;"}, {"'", "&apos;"}}) do
        result = replace_plain(result, replacement[1], replacement[2])
    end
    return result
end
local function contains(values, wanted)
    for _, value in ipairs(values or {}) do if value == wanted then return true end end
    return false
end
local function colors_match(card_colors)
    if #selected_colors == 0 then return true end
    if #card_colors ~= #selected_colors then return false end
    for _, color in ipairs(selected_colors) do
        if not contains(card_colors, color) then return false end
    end
    return true
end
local function canonical_name(id)
    local card = by_id[id]
    if not card then return "" end
    local base = by_id[card.canonical] or card
    return base.name
end
local function allowed(card, rule)
    if not card or not card.constructible or card.token then return false end
    return rule ~= "official" or not banned_spx[card.id]
end
local function main_limit(rule) return rule == "test" and 70 or 50 end
local function limit(card, rule)
    if not allowed(card, rule) then return 0 end
    if rule == "test" then return -1 end
    if contains(card.keywords, "终言") then return 1 end
    if contains(card.keywords, "限制级") or contains(card.keywords, "限制级符卡") then return 2 end
    if (rule == "official" or rule == "official_spx") and official_two[card.id] then return 2 end
    if card.unlimited then return -1 end
    return 4
end
local function copy_count(id)
    local key, count = canonical_name(id), 0
    for _, zone in ipairs({draft.main, draft.side}) do
        for _, other in ipairs(zone) do if canonical_name(other) == key then count = count + 1 end end
    end
    return count
end
local function validate(deck, strict)
    if type(deck) ~= "table" or type(deck.name) ~= "string" or deck.name:match("^%s*$") then return "请输入卡组名称。" end
    if #deck.name > 120 then return "卡组名称过长。" end
    if type(deck.main) ~= "table" or type(deck.side) ~= "table" then return "主副卡组格式错误。" end
    local rule = deck.rule_set
    if not rule_labels[rule] then return "规则集无效。" end
    if #deck.main > main_limit(rule) or #deck.side > 10 then return "主牌或备牌超出容量。" end
    if not by_id[deck.leader] or by_id[deck.leader].kind ~= "自机" or not allowed(by_id[deck.leader], rule) then
        return "请先选择合法自机。"
    end
    if strict and rule ~= "test" and #deck.main ~= 50 then return "主卡组需要恰好 50 张。" end
    local counts = {}
    for _, zone in ipairs({deck.main, deck.side}) do
        for _, id in ipairs(zone) do
            local card = by_id[id]
            if not allowed(card, rule) then return "卡组包含未知或不可构筑卡牌。" end
            local key = canonical_name(id)
            if rule ~= "test" and key == canonical_name(deck.leader) then return "主副牌不能与自机同名。" end
            counts[key] = (counts[key] or 0) + 1
            local maximum = limit(card, rule)
            if maximum >= 0 and counts[key] > maximum then return "同名牌超过上限：" .. key end
        end
    end
    return nil
end
local function prune_for_rule(rule)
    local removed, counts = 0, {}
    draft.rule_set = rule
    if not allowed(by_id[draft.leader], rule) then draft.leader = "" end
    local leader_name = canonical_name(draft.leader)
    for _, key in ipairs({"main", "side"}) do
        local kept = {}
        for _, id in ipairs(draft[key]) do
            local card, name = by_id[id], canonical_name(id)
            local maximum = limit(card, rule)
            local capacity = key == "main" and main_limit(rule) or 10
            if card and maximum ~= 0 and #kept < capacity and (rule == "test" or name ~= leader_name)
                and (maximum < 0 or (counts[name] or 0) < maximum) then
                kept[#kept + 1] = id
                counts[name] = (counts[name] or 0) + 1
            else removed = removed + 1 end
        end
        draft[key] = kept
    end
    return removed
end
local function status(text) message = text or "" end
local function make_button(id, label, width, color)
    return '<Button id="' .. xml(id) .. '" onClick="onDeckClick" preferredWidth="' .. width ..
        '" preferredHeight="36" fontSize="18" textColor="#FFFFFF" colors="' ..
        (color or "#334B63|#486A87|#263B50|#555555") .. '">' .. xml(label) .. '</Button>'
end
local function make_text(value, width, height, size)
    return '<Text preferredWidth="' .. width .. '" preferredHeight="' .. (height or 36) ..
        '" fontSize="' .. (size or 18) .. '" color="#F3F5F7" alignment="MiddleLeft" ' ..
        'horizontalOverflow="Wrap">' .. xml(value) .. '</Text>'
end
local function row(contents)
    return '<HorizontalLayout preferredHeight="40" childForceExpandWidth="false" spacing="4">' ..
        table.concat(contents) .. '</HorizontalLayout>'
end
local function dropdown(id, items, chosen, width)
    local options = {}
    for _, item in ipairs(items) do
        options[#options + 1] = '<Option' .. (item == chosen and ' selected="true"' or '') .. '>' .. xml(item) .. '</Option>'
    end
    return '<Dropdown id="' .. xml(id) .. '" onValueChanged="onDeckChoice" preferredWidth="' .. width ..
        '" preferredHeight="36" fontSize="18" textColor="#222222">' .. table.concat(options) .. '</Dropdown>'
end
local function library_cards()
    local result, needle = {}, search:lower()
    for _, card in ipairs(cards) do
        if card.id == card.canonical
            and (kind_filter == "全部" or card.kind == kind_filter)
            and colors_match(card.colors) then
            local haystack = (card.name .. " " .. card.id .. " " .. table.concat(card.aliases or {}, " ")):lower()
            if card.token then haystack = haystack .. " 衍生物" end
            if not card.constructible then haystack = haystack .. " 不可构筑" end
            if needle == "" or haystack:find(needle, 1, true) then result[#result + 1] = card end
        end
    end
    table.sort(result, function(a, b)
        if sort_mode == "类别" and a.kind ~= b.kind then return kind_rank[a.kind] < kind_rank[b.kind] end
        if sort_mode == "颜色值" then
            local ac, bc = table.concat(a.colors, "/"), table.concat(b.colors, "/")
            if ac ~= bc then return ac < bc end
        end
        if sort_mode ~= "名字" and a.cost ~= b.cost then return a.cost < b.cost end
        return a.name < b.name
    end)
    return result
end
local function unique_rows(zone)
    local result, indexes = {}, {}
    for _, id in ipairs(zone) do
        if not indexes[id] then
            indexes[id] = #result + 1
            result[#result + 1] = {id = id, count = 0}
        end
        result[indexes[id]].count = result[indexes[id]].count + 1
    end
    return result
end
local function card_rows(zone_name, page, size)
    local list = unique_rows(draft[zone_name])
    local max_page = math.max(1, math.ceil(#list / size))
    page = math.min(math.max(1, page), max_page)
    if zone_name == "main" then main_page = page else side_page = page end
    local out = {row({make_text(zone_name == "main" and "主卡组" or "备牌", 160, 36, 21),
        make_button(zone_name .. "prev", "◀", 46),
        make_text(page .. "/" .. max_page, 65),
        make_button(zone_name .. "next", "▶", 46)})}
    for i = (page - 1) * size + 1, math.min(page * size, #list) do
        local entry, card = list[i], by_id[list[i].id]
        out[#out + 1] = row({make_button("select:" .. entry.id, card.name, 390),
            make_text("×" .. entry.count, 50), make_button("remove:" .. zone_name .. ":" .. entry.id, "−", 42)})
    end
    return table.concat(out)
end
local function render()
    local parts = {}
    parts[#parts + 1] = '<Button id="toggle" onClick="onDeckClick" rectAlignment="UpperLeft" offsetXY="12 -12" width="135" height="42" fontSize="20" colors="#31647D|#4683A0|#26485A|#555555" textColor="#FFFFFF">组卡器</Button>'
    if not open then UI.setXml(table.concat(parts)); return end
    parts[#parts + 1] = '<Panel id="builder" width="1560" height="960" rectAlignment="MiddleCenter" color="#17232EF2">'
    parts[#parts + 1] = '<VerticalLayout padding="14 14 14 14" spacing="6" childForceExpandHeight="false">'
    parts[#parts + 1] = row({make_text("极彩组卡器", 220, 40, 28),
        '<InputField id="deck_name" onEndEdit="onDeckField" text="' .. xml(draft.name) .. '" preferredWidth="340" preferredHeight="38" fontSize="20" />',
        dropdown("rule", {"无限制", "官限", "官限有限定卡", "测试卡组"}, rule_labels[draft.rule_set], 190),
        make_text("主牌 " .. #draft.main .. "/" .. main_limit(draft.rule_set) .. "  备牌 " .. #draft.side .. "/10", 245),
        make_button("close", "关闭", 90)})
    parts[#parts + 1] = row({make_button("new", "新建", 90), make_button("save", "保存卡组", 120),
        make_button("load", "载入", 90), make_button("delete", delete_pending and "确认删除" or "删除卡组", 120),
        make_button("export", "导出代码", 120),
        make_button("import", "导入代码", 120), make_button("spawn", "生成卡组", 120, "#487954|#5C9667|#345B3B|#555555"),
        make_button("sort", "整理主副牌", 130),
        dropdown("saved", (function()
            local names = {"选择已存卡组"}
            for name in pairs(saved_decks) do names[#names + 1] = name end
            table.sort(names)
            return names
        end)(), selected_saved == "" and "选择已存卡组" or selected_saved, 240)})
    parts[#parts + 1] = '<HorizontalLayout preferredHeight="680" spacing="12" childForceExpandWidth="false">'
    parts[#parts + 1] = '<Panel preferredWidth="850" preferredHeight="680" color="#213240"><VerticalLayout padding="8 8 8 8" spacing="3" childForceExpandHeight="false">'
    parts[#parts + 1] = row({'<InputField id="search" onEndEdit="onDeckField" text="' .. xml(search) ..
        '" placeholder="搜索名称、编号、别名" preferredWidth="390" preferredHeight="36" fontSize="18" />',
        dropdown("kind", kinds, kind_filter, 165), dropdown("sort_mode", sorts, sort_mode, 165)})
    local color_buttons = {make_text("颜色严格匹配：", 140)}
    for _, color in ipairs(colors) do
        local active = color == "全部" and #selected_colors == 0 or contains(selected_colors, color)
        color_buttons[#color_buttons + 1] = make_button("color:" .. color,
            (active and "✓" or "") .. color, 80, active and "#317C75|#40958B|#225E58|#555555" or nil)
    end
    parts[#parts + 1] = row(color_buttons)
    local result = library_cards()
    local max_page = math.max(1, math.ceil(#result / 10))
    library_page = math.min(math.max(1, library_page), max_page)
    parts[#parts + 1] = row({make_text("卡库 " .. #result .. " 张", 180), make_button("libprev", "◀", 50),
        make_text(library_page .. "/" .. max_page, 90), make_button("libnext", "▶", 50),
        make_text("点击名称预览牌文和卡面", 310)})
    for i = (library_page - 1) * 10 + 1, math.min(library_page * 10, #result) do
        local card = result[i]
        local summary = card.name .. "  [" .. card.kind .. " " .. table.concat(card.colors, "/") .. " " .. card.cost .. "]" ..
            (allowed(card, draft.rule_set) and "" or " · 不可加入")
        parts[#parts + 1] = row({make_button("select:" .. card.id, summary, 595),
            make_button("addmain:" .. card.id, card.kind == "自机" and "设自机" or "+主", 100),
            make_button("addside:" .. card.id, "+备", 75)})
    end
    local selected = by_id[selected_id]
    local detail = selected and (selected.name .. "｜" .. selected.id .. "｜" .. selected.rules) or "选一张牌查看说明；预览会在鼠标附近生成临时卡面。"
    parts[#parts + 1] = make_text(detail, 830, 95, 17)
    parts[#parts + 1] = '</VerticalLayout></Panel>'
    parts[#parts + 1] = '<Panel preferredWidth="665" preferredHeight="680" color="#213240"><VerticalLayout padding="8 8 8 8" spacing="3" childForceExpandHeight="false">'
    local leader = by_id[draft.leader]
    parts[#parts + 1] = row({make_text("自机：" .. (leader and leader.name or "未选择"), 600, 38, 20)})
    parts[#parts + 1] = card_rows("main", main_page, 8)
    parts[#parts + 1] = card_rows("side", side_page, 4)
    parts[#parts + 1] = '</VerticalLayout></Panel></HorizontalLayout>'
    parts[#parts + 1] = row({make_text(message, 1500, 38, 18)})
    parts[#parts + 1] = '<InputField id="deck_code" onEndEdit="onDeckField" text="' .. xml(code_text) ..
        '" placeholder="在这里粘贴或复制项目 .mdeck JSON" lineType="MultiLineNewLine" preferredHeight="100" fontSize="16" />'
    parts[#parts + 1] = '</VerticalLayout></Panel>'
    UI.setXml(table.concat(parts))
end

local function card_data(id)
    local card = by_id[id]
    if not card then return nil end
    return {
        Name = "Card", CardID = card.card_id, CustomDeck = {[card.deck_id] = assets[card.deck_id]},
        SidewaysCard = card.sideways, Nickname = card.name, Description = card.rules,
        Transform = {posX = 0, posY = 5, posZ = 0, rotX = 0, rotY = 180, rotZ = 0,
            scaleX = 1, scaleY = 1, scaleZ = 1}, ColorDiffuse = {r = 1, g = 1, b = 1},
        Hands = true, Locked = false, Grid = true, Snap = true, Autoraise = true,
        Sticky = true, Tooltip = true, LuaScript = "", LuaScriptState = "", XmlUI = "", GUID = "deadbf"
    }
end
local function spawn_card(id, player)
    if preview_object and not preview_object.isDestroyed() then preview_object.destruct() end
    local p = player.getPointerPosition()
    preview_object = spawnObjectData({data = card_data(id), position = {p.x, math.max(p.y + 2, 2), p.z},
        rotation = {0, 180, 0}, callback_function = function(obj) obj.setLock(true) end})
    if by_id[id].local_art then status("这张牌使用本地卡图；联机前请把其图片上传至 TTS Cloud。") end
end
local function spawn_deck(player)
    local error = validate(draft, true)
    if error then status(error); return end
    local deck = {Name = "Deck", Nickname = draft.name, Description = "极彩组卡器生成",
        DeckIDs = {}, CustomDeck = {}, ContainedObjects = {}, Hands = false,
        Transform = {posX = 0, posY = 5, posZ = 0, rotX = 0, rotY = 180, rotZ = 0,
            scaleX = 1, scaleY = 1, scaleZ = 1}, ColorDiffuse = {r = 1, g = 1, b = 1},
        Locked = false, Grid = true, Snap = true, Autoraise = true, Sticky = true,
        Tooltip = true, LuaScript = "", LuaScriptState = "", XmlUI = "", GUID = "deadbf"}
    local local_count = 0
    for _, id in ipairs(draft.main) do
        local card = card_data(id)
        deck.DeckIDs[#deck.DeckIDs + 1] = card.CardID
        deck.CustomDeck[by_id[id].deck_id] = assets[by_id[id].deck_id]
        deck.ContainedObjects[#deck.ContainedObjects + 1] = card
        if by_id[id].local_art then local_count = local_count + 1 end
    end
    local p = player.getPointerPosition()
    spawnObjectData({data = deck, position = {p.x, math.max(p.y + 3, 3), p.z}, rotation = {0, 180, 0}})
    local leader = spawnObjectData({data = card_data(draft.leader),
        position = {p.x - 3, math.max(p.y + 3, 3), p.z}, rotation = {0, 180, 0}})
    if leader then leader.setName("自机｜" .. by_id[draft.leader].name) end
    for i, id in ipairs(draft.side) do
        local side = spawnObjectData({data = card_data(id),
            position = {p.x + 3 + (i - 1) * 1.5, math.max(p.y + 3, 3), p.z}, rotation = {0, 180, 0}})
        if side then side.addTag("极彩备牌") end
        if by_id[id].local_art then local_count = local_count + 1 end
    end
    if by_id[draft.leader].local_art then local_count = local_count + 1 end
    status("已生成主牌、自机及备牌。" .. (local_count > 0 and ("其中 " .. local_count .. " 张使用本地卡图。") or ""))
end

function onLoad(saved_state)
    if saved_state and saved_state ~= "" then
        local ok, state = pcall(JSON.decode, saved_state)
        if ok and type(state) == "table" then
            if type(state.draft) == "table" and type(state.draft.main) == "table" and
                type(state.draft.side) == "table" then draft = state.draft end
            if type(state.saved) == "table" then saved_decks = state.saved end
        end
    end
    render()
end

function onSave()
    return JSON.encode({draft = draft, saved = saved_decks})
end

function onDeckField(player, value, id)
    if id == "deck_name" then draft.name = value
    elseif id == "search" then search = value; library_page = 1
    elseif id == "deck_code" then code_text = value end
    if id ~= "deck_code" then render() end
end

function onDeckChoice(player, value, id)
    if id == "kind" then kind_filter = value; library_page = 1
    elseif id == "sort_mode" then sort_mode = value; library_page = 1
    elseif id == "saved" then selected_saved = value == "选择已存卡组" and "" or value; delete_pending = false
    elseif id == "rule" then
        for _, rule in ipairs(rule_order) do
            if rule_labels[rule] == value then
                local removed = prune_for_rule(rule)
                status("已切换规则集。" .. (removed > 0 and ("移除不合法卡牌 " .. removed .. " 张。") or ""))
                break
            end
        end
    end
    render()
end

function onDeckClick(player, value, id)
    if id == "toggle" or id == "close" then
        open = id == "toggle" and not open or false
        render(); return
    end
    local action, zone, card_id = id:match("^([^:]+):([^:]+):(.+)$")
    if not action then action, card_id = id:match("^([^:]+):(.+)$") end
    if action == "select" and by_id[card_id] then
        selected_id = card_id
        spawn_card(card_id, player)
    elseif action == "color" then
        if card_id == "全部" then selected_colors = {}
        else
            local present = false
            for i = #selected_colors, 1, -1 do
                if selected_colors[i] == card_id then table.remove(selected_colors, i); present = true end
            end
            if not present then selected_colors[#selected_colors + 1] = card_id end
        end
        library_page = 1
    elseif action == "addmain" or action == "addside" then
        local card = by_id[card_id]
        if not allowed(card, draft.rule_set) then status("该牌不能加入当前规则集。")
        elseif card.kind == "自机" and action == "addmain" then
            draft.leader = card_id
            local name = canonical_name(card_id)
            for _, key in ipairs({"main", "side"}) do
                local kept = {}
                for _, other in ipairs(draft[key]) do
                    if canonical_name(other) ~= name then kept[#kept + 1] = other end
                end
                draft[key] = kept
            end
            status("已选择自机：" .. card.name)
        elseif card.kind == "自机" then status("自机只能放在自机位。")
        else
            local key = action == "addmain" and "main" or "side"
            local maximum = limit(card, draft.rule_set)
            local capacity = key == "main" and main_limit(draft.rule_set) or 10
            if canonical_name(card_id) == canonical_name(draft.leader) then
                status("主副牌不能与自机同名。")
            elseif #draft[key] >= capacity then status("该区域已满。")
            elseif maximum >= 0 and copy_count(card_id) >= maximum then status("同名牌已达到上限。")
            else draft[key][#draft[key] + 1] = card_id; status("已加入" .. (key == "main" and "主牌" or "备牌") .. "：" .. card.name) end
        end
    elseif action == "remove" and draft[zone] then
        for i = #draft[zone], 1, -1 do
            if draft[zone][i] == card_id then table.remove(draft[zone], i); break end
        end
    elseif id == "libprev" then library_page = library_page - 1
    elseif id == "libnext" then library_page = library_page + 1
    elseif id == "mainprev" then main_page = main_page - 1
    elseif id == "mainnext" then main_page = main_page + 1
    elseif id == "sideprev" then side_page = side_page - 1
    elseif id == "sidenext" then side_page = side_page + 1
    elseif id == "new" then
        draft = {name = "未命名卡组", main = {}, side = {}, leader = "", rule_set = "official"}
        delete_pending = false
        status("已建立空白卡组。")
    elseif id == "save" then
        local error = validate(draft, false)
        if error then status(error) else saved_decks[draft.name] = clone(draft); selected_saved = draft.name; status("已保存；请保存 TTS 游戏以永久保留。") end
    elseif id == "load" then
        if saved_decks[selected_saved] then draft = clone(saved_decks[selected_saved]); status("已载入：" .. selected_saved)
        else status("请先选择已存卡组。") end
        delete_pending = false
    elseif id == "delete" then
        if not saved_decks[selected_saved] then status("请先选择已存卡组。")
        elseif not delete_pending then delete_pending = true; status("再次点击“确认删除”以删除已存卡组。")
        else
            saved_decks[selected_saved] = nil
            status("已删除已存卡组：" .. selected_saved)
            selected_saved = ""
            delete_pending = false
        end
    elseif id == "sort" then
        local function less(a, b)
            local ca, cb = by_id[a], by_id[b]
            if sort_mode == "类别" and ca.kind ~= cb.kind then return kind_rank[ca.kind] < kind_rank[cb.kind] end
            if sort_mode == "颜色值" then
                local ac, bc = table.concat(ca.colors, "/"), table.concat(cb.colors, "/")
                if ac ~= bc then return ac < bc end
            end
            if sort_mode ~= "名字" and ca.cost ~= cb.cost then return ca.cost < cb.cost end
            return ca.name < cb.name
        end
        table.sort(draft.main, less); table.sort(draft.side, less); status("已整理主副牌。")
    elseif id == "export" then
        code_text = JSON.encode({format = "multicolor:arena/deck", version = 1, deck = draft})
        status("卡组代码已写入下方文本框，可复制到项目组卡器。")
    elseif id == "import" then
        local ok, data = pcall(JSON.decode, code_text)
        if not ok or type(data) ~= "table" then status("卡组代码不是有效 JSON。")
        else
            local incoming = data.deck or data
            local error = validate(incoming, false)
            if error then status("导入失败：" .. error)
            else draft = clone(incoming); status("已导入卡组：" .. draft.name) end
        end
    elseif id == "spawn" then spawn_deck(player) end
    render()
end
